/******************************************************************************
 * @file               : drive_encoder.c
 * @brief              : 编码器驱动模块，用于处理编码器信号并计算电机位置和速度
 * ****************************************************************************
 *  @attention
 *        Copyright  :   沉沙电机
 *        微信一号   :   ChenSha_Motor
 *        微信二号   :   Chensha_motor67
 *        CSDN账号   :   沉沙丶
 *        CSDN网址   :   https://blog.csdn.net/sy243772901
 *        知乎       :   沉沙motor一下
 *        知乎网址   :   https://www.zhihu.com/people/gun-ne-ni
 *        淘宝       :   沉沙的科技小店
 *        淘宝链接   :   https://shop256076681.taobao.com/
 *   All rights reserved.
 * ****************************************************************************
 *    modification history :
 *    Date:           Version:        Author:
 *    Changes:
 ******************************************************************************/

/* Includes ------------------------------------------------------------------*/
#include "AbzEncoder.h"
#include "main.h"
#include "arm_math.h"
#include "utils_math.h"
#include "define.h"
#include "common_function.h"

/* Private defines -----------------------------------------------------------*/
// 编码器计数范围定义（三角波范围）
#define ENCODER_CNT_MIN        0               // 最小计数值
#define ENCODER_CNT_MAX        10000           // 最大计数值
#define ENCODER_CNT_PERIOD     (ENCODER_CNT_MAX - ENCODER_CNT_MIN)  // 计数周期
#define ENCODER_CNT_HALF_PERIOD (ENCODER_CNT_PERIOD / 2)            // 半周期，用于判断拐点

// 编码器位置计算常量
#define POS_SCALE_FACTOR       (1 << 16L)      // 位置计算的缩放因子(65536)，用于提高精度
#define POS_SCALE_INV          (1.0f / 65536.0f) // 缩放因子的倒数，用于还原实际位置

// 速度限制参数
#define MAX_SPEED              3500.0f         // 最大速度限制(转/分)
#define MIN_SPEED              -3500.0f        // 最小速度限制(转/分)

/* Private variables ---------------------------------------------------------*/
Drive_Encoder_Str g_encoder;  // 编码器全局实例

/* Private function prototypes -----------------------------------------------*/
void     Encoder_Param_Update(Drive_Encoder_Str *p);  // 更新编码器参数
void     Encoder_Get_Pos(Drive_Encoder_Str *p);        // 获取编码器位置
void     Encoder_Get_Speed(Drive_Encoder_Str *p);      // 获取编码器速度
void     Encoder_ForceAngle(Drive_Encoder_Str *p, float Pos);  // 强制设置角度
uint32_t Encoder_Get_Qep_Origin_Cnt(void);             // 获取原始QEP计数值

/* Private function ----------------------------------------------------------*/

/**
 * @brief  更新编码器参数配置
 * @param  p: 编码器结构体指针
 * @retval None
 */
void Encoder_Param_Update(Drive_Encoder_Str *p)
{
    // 电机和编码器基本参数配置
    p->input.motor_poles       = 5;                  // 电机极对数
    p->input.encoder_poles     = 1;                  // 编码器极对数
    p->input.encoder_pulse     = EncoderPulse_default;// 编码器线数
    p->input.freq_base         = 250.0f;             // 电机基频(Hz)

    // 位置计算系数
    p->inner.pos_coff_num      = p->input.motor_poles * POS_SCALE_FACTOR;  // 分子系数: 极对数 * 65536
    p->inner.pos_coff_den      = p->input.encoder_poles * (p->input.encoder_pulse << 2);  // 分母系数: 编码器极对数 * 四倍频线数

    p->inner.encoder_dir       = 1;                   // 编码器方向(1:正向, 0:反向)

    // 速度计算相关参数
    p->input.Qep_clk           = TIM_CLOCK_FREQ_HZ;   // 编码器采样频率(控制器主频)
    p->inner.speed_coff        = 60 * TIM_CLOCK_FREQ_HZ / p->inner.pos_coff_den;          // 速度计算系数
    
    // 时间参数配置
    p->inner.m_delta_time_max  = 500 * 170;           // 最大时间差(对应500us)，超过此值则进行速度计算
    
    // 滤波器参数
    p->inner.speed_LPF1st.coff = 0.001f;              // 速度一阶低通滤波系数 Ts/(2*Tor + Ts)
}

/**
 * @brief  获取并计算编码器位置信息
 * @param  p: 编码器结构体指针
 * @retval None
 */
void Encoder_Get_Pos(Drive_Encoder_Str *p)
{
    int32_t m_delta_pos;  // 位置增量(中间变量，扩大为32位防止溢出)
    int32_t m_add;        // 位置累加值(中间变量)

    // Step 1: 读取原始脉冲计数值和系统时间
    p->input.cnt_origin = Encoder_Get_Qep_Origin_Cnt();  // 获取当前编码器计数值
    p->inner.m_time     = Get_System_Time();             // 获取系统时间(TIM2计时器)

    // Step 2: 计算脉冲计数值增量并处理三角波拐点
    p->inner.cnt_delta  = p->input.cnt_origin - p->inner.cnt_last;  // 计算原始差值
    p->inner.cnt_last   = p->input.cnt_origin;                      // 更新上一次计数值

    // 处理编码器方向(反转时取反)
    if (0 == p->inner.encoder_dir)
    {
        p->inner.cnt_delta = -p->inner.cnt_delta;
    }

    // 处理三角波拐点导致的异常delta值
    // 当delta为正且超过半周期，说明是负向跳变(需要修正)
    if (p->inner.cnt_delta > ENCODER_CNT_HALF_PERIOD) 
    {
        p->inner.cnt_delta -= ENCODER_CNT_PERIOD;
    }
    // 当delta为负且绝对值超过半周期，说明是正向跳变(需要修正)
    else if (p->inner.cnt_delta < -ENCODER_CNT_HALF_PERIOD) 
    {
        p->inner.cnt_delta += ENCODER_CNT_PERIOD;
    }

    // Step 3: 计算编码器角度(带缩放处理以提高精度)
    // 计算带缩放的位置增量: cnt_delta * 极对数 * 65536 + 上一次余数
    m_delta_pos = p->inner.cnt_delta * p->input.motor_poles * POS_SCALE_FACTOR + p->inner.remain;
    
    // 计算商值(位置增量)和余数(用于下次计算)
    m_add = m_delta_pos / p->inner.pos_coff_den;                // 计算位置累加值
    p->inner.remain = m_delta_pos - m_add * p->inner.pos_coff_den;  // 更新余数

    // Step 4: 累加位置增量并转换为实际角度值
    // 编码器位置计算
    p->output.encoder_pos_Q16 += (int16_t)m_add;               // 累加Q16格式位置
    p->output.encoder_pos      = p->output.encoder_pos_Q16 * POS_SCALE_INV;  // 转换为实际角度

    // 转子位置计算
    p->output.rotor_pos_Q16   += (int16_t)m_add;               // 累加Q16格式转子位置
    p->output.rotor_pos        = p->output.rotor_pos_Q16 * POS_SCALE_INV;  // 转换为实际转子角度
    // p->output.rotor_pos_Q16   += (int16_t)p->output.adjust_z_pos; // z信号使用 暂时不启用  
}

/**
 * @brief  强制设置编码器角度(预留函数)
 * @param  Pos: 要设置的角度值
 * @retval None
 */
// void Encoder_ForceAngle(Drive_Encoder_Str *p, float Pos)
// {
//     DINT;  // 禁用中断
//     p->output.encoder_pos_Q16  = (int16_t)(Pos * 65536.0f);  // 设置Q16格式编码器位置
//     p->output.rotor_pos_Q16    = (int16_t)(Pos * 65536.0f);  // 设置Q16格式转子位置
//     p->output.encoder_pos      = Pos;                        // 设置实际编码器位置
//     p->output.rotor_pos        = Pos;                        // 设置实际转子位置
//     EINT;  // 使能中断
// }

/**
 * @brief  计算编码器速度信息
 * @param  p: 编码器结构体指针
 * @retval None
 */
void Encoder_Get_Speed(Drive_Encoder_Str *p)
{
    p->input.speed_mear_prd = TIM_ARR;  // 获取定时器自动重装载值

    // 计算时间差(当前时间 - 上一次时间)
    p->inner.m_delta_time   = p->inner.m_time - p->inner.m_time_bak;
    
    // 当时间差超过设定最大值时，计算速度
    if (p->inner.m_delta_time > p->inner.m_delta_time_max)
    {
        // 计算位置增量
        p->inner.m_delta_pos = p->input.cnt_origin - p->inner.m_pos_bak;
        
        // 处理编码器方向
        if (0 == p->inner.encoder_dir)
        {
            p->inner.m_delta_pos = -p->inner.m_delta_pos;
        }
        
        // 更新位置和时间备份
        p->inner.m_pos_bak  = p->input.cnt_origin;  // 保存当前位置
        p->inner.m_time_bak = p->inner.m_time;       // 保存当前时间

        // 计算未滤波速度
        // 速度公式: 脉冲差值 * 速度系数 / 时间差
        // 1020000 = 速度计算系数 = 60 * 主频 / 一圈编码器脉冲数
        p->output.speed_unsmooth = p->inner.m_delta_pos * 1020000.f / p->inner.m_delta_time;
        
        // 速度限幅
        if (p->output.speed_unsmooth > MAX_SPEED)
        {
            p->output.speed_unsmooth = MAX_SPEED;
        }
        if (p->output.speed_unsmooth < MIN_SPEED)
        {
            p->output.speed_unsmooth = MIN_SPEED;
        }
    }
    
    // 速度滤波处理
    p->inner.speed_LPF1st.input = p->output.speed_unsmooth;  // 输入未滤波速度
    LPF1st_Float(&p->inner.speed_LPF1st);                    // 一阶低通滤波
    p->output.speed_smooth = p->inner.speed_LPF1st.out;       // 输出滤波后速度
}

/**
 * @brief  获取QEP编码器原始计数值
 * @param  None
 * @retval 编码器计数值
 */
uint32_t Encoder_Get_Qep_Origin_Cnt(void)
{
    return __HAL_TIM_GET_COUNTER(&htim3);  // 读取TIM3计数器值
}
