

#ifndef __AbzEncoder_H__
#define __AbzEncoder_H__

/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "common_function.h"
/* Exported macro ------------------------------------------------------------*/
#define EncoderPulse_default (2500)

#define Get_System_Time() (TIM2->CNT)
/* Exported types ------------------------------------------------------------*/
typedef struct Drive_Encoder_Str_Input_Def
{
    uint32_t cnt_origin;     // 原始脉冲计数值

    uint16_t motor_poles;    // 电机极对数
    uint16_t encoder_poles;  // 编码器极对数
    float    freq_base;      // 转速基值     Unit_Hz_Q0

    uint32_t encoder_pulse;  // 编码器线数

    float    speed_mear_prd; // 测速时间间隔 Unit_s_Q0

    uint32_t Qep_clk;        // Qep的时钟    Unit_Hz_Q0

} Drive_Encoder_Input_Str;

typedef struct Drive_Encoder_Str_Inner_Def
{
    uint32_t         cnt_last;
    int32_t          cnt_delta;
    uint16_t         encoder_dir;      // 编码器旋转方向 只有 0 - 和电机相序同向 和 1 - 和电机相序反向 两个方向

    int32_t          pos_coff_num;     // 计算角度系数分子
    int32_t          pos_coff_den;     // 计算角度系数分母

    int32_t          remain;           // 定点除法余数

    float            speed_coff;       // 计算转速系数
    uint32_t         m_pos_bak;        // M法保存的上次计算的位置
    uint32_t         m_time;           // M法计算时间
    uint32_t         m_time_bak;       // M法计算时间保存值
    int32_t          m_delta_pos;      // M法的deltaPos
    int32_t          m_delta_time;     // M法的deltaTime
    int32_t          m_delta_time_max; // M法的deltaTime 的最大值
    LPF1st_Float_Str speed_LPF1st;     // 转速一阶低通滤波
} Drive_Encoder_Inner_Str;

typedef struct Drive_Encoder_Str_OutPut_Def
{
    int16_t encoder_pos_Q16; // 编码器角度                   Unit_PU_Q16
    int16_t rotor_pos_Q16;   // 转子角度                     Unit_PU_Q16
    int16_t adjust_z_pos;    // Z信号到来时校准的角度增量    Unit_PU_Q16
    float   encoder_pos;     // 编码器角度                   Unit_PU_Q0
    float   rotor_pos;       // 转子角度                     Unit_PU_Q0

    float   speed_unsmooth;  // 未滤波转速                   Unit_PU_Q0
    float   speed_smooth;    // 滤波转速                     Unit_PU_Q0
} Drive_Encoder_OutPut_Str;

typedef struct Drive_Encoder_Str_Def
{
    Drive_Encoder_Input_Str  input;  // 输入
    Drive_Encoder_Inner_Str  inner;  // 处理
    Drive_Encoder_OutPut_Str output; // 输出
} Drive_Encoder_Str;
/* Exported constants --------------------------------------------------------*/

/* Exported functions prototypes ---------------------------------------------*/

/* Private defines -----------------------------------------------------------*/

extern void              Encoder_Param_Update(Drive_Encoder_Str *p);
extern void              Encoder_Get_Pos(Drive_Encoder_Str *p);
extern void              Encoder_Get_Speed(Drive_Encoder_Str *p);
extern void              Encoder_ForceAngle(Drive_Encoder_Str *p,float Pos);
extern Drive_Encoder_Str g_encoder;


#endif
