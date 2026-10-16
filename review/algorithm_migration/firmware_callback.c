#include "main.h"
#include "debug.h"
#include "foc.h"
#include "control.h"
#include "PositionSensor.h"
#include "cvsensor.h"
#include "identify.h"
#include "define.h"
#include "arm_math.h"
#include "utils_math.h"
#include "AbzEncoder.h"

/* -------------------------- 宏定义与枚举定义 -------------------------- */
// 数学与物理常量
#define SQ(x)               ((x) * (x))                  // 平方运算宏
#define ANGLE_MAX           PI                           // 最大角度(弧度)
#define ANGLE_MIN           -PI                          // 最小角度(弧度)
#define ENCODER_MAX_CNT     10000                        // 编码器最大计数
#define SPEED_LOOP_DIV      10                           // 速度环分频系数(50us*10=500us)
#define SPEED_LPF_ALPHA     0.995f                       // 速度低通滤波系数
#define SPEED_LPF_BETA      (1.0f - SPEED_LPF_ALPHA)     // 滤波系数补值

// 控制模式枚举（替代数字0/1/2，增强可读性）
typedef enum {
    CTRL_MODE_OPEN_LOOP = 0,  // 开环VF控制
    CTRL_MODE_CURRENT_LOOP,   // 电流闭环IF控制
    CTRL_MODE_SPEED_LOOP      // 速度闭环控制
} ControlMode_e;

/* -------------------------- 全局变量声明 -------------------------- */
float32_t temp_setIq = 0.0f;  // 临时Q轴电流设定值

// 调试与状态变量
uint32_t Jtime = 0;           // 调试计时器
uint32_t Dt1 = 0, Dt2 = 0;    // 时间差值变量
uint32_t st = 0, posinf = 0;  // 状态与位置信息变量
float speedset = 0.0f;        // 速度设定值

/* -------------------------- 静态函数声明 -------------------------- */
__STATIC_FORCEINLINE void Limiting_float(float *value, float upRang, float lowRang);
static void CurrentVoltageSampling(void);               // 电流电压采样处理
static void SpeedCalculation(void);                     // 速度计算与滤波
static void CurrentLoopCommonProcess(void);             // 电流环公共处理逻辑
static void OpenLoopControlProcess(void);               // 开环控制逻辑处理
static void CurrentLoopControlProcess(void);            // 电流闭环控制逻辑处理
static void SpeedLoopControlProcess(void);              // 速度闭环控制逻辑处理

/* -------------------------- 函数实现 -------------------------- */

/**
 * @brief  浮点型限幅函数
 * @param  value: 待限幅的变量指针
 * @param  upRang: 上限值
 * @param  lowRang: 下限值
 * @note   确保变量值在[lowRang, upRang]范围内
 */
__STATIC_FORCEINLINE void Limiting_float(float *value, float upRang, float lowRang)
{
    if (*value > upRang) {
        *value = upRang;
    } else if (*value < lowRang) {
        *value = lowRang;
    }
}

/**
 * @brief  电流与电压采样处理
 * @note   读取ADC原始值并转换为实际电流、电压值（考虑增益和偏置）
 */
static void CurrentVoltageSampling(void)
{
    // 读取ADC注入通道原始值
    CurrentSensor.PHASE_A_ADCval = ADC1->JDR1;
    CurrentSensor.PHASE_B_ADCval = ADC2->JDR1;
    CurrentSensor.PHASE_C_ADCval = ADC3->JDR1;
    VoltageSensor.VBUS_ADCval = ADC3->JDR2;

    // 电流值转换：3.0V参考电压，12位ADC(4095)，去除1.5V（1.5V对应0A）偏置，除以增益和采样电阻
    // 采样芯片型号及配置 请查询硬件手册；
    // 该采样增益以及芯片的使用请查询INA241A2数据手册；
    CurrentSensor.PHASE_A_REALval = ((CurrentSensor.PHASE_A_ADCval * 3.0f) / 4095.0f - 1.5f) 
                                  / GAIN_50 / RES_1_mOhm;
    CurrentSensor.PHASE_B_REALval = ((CurrentSensor.PHASE_B_ADCval * 3.0f) / 4095.0f - 1.5f) 
                                  / GAIN_50 / RES_1_mOhm;
    CurrentSensor.PHASE_C_REALval = ((CurrentSensor.PHASE_C_ADCval * 3.0f) / 4095.0f - 1.5f) 
                                  / GAIN_50 / RES_1_mOhm;

    User_Debug.Ia = CurrentSensor.PHASE_A_REALval ;
    User_Debug.Ib = CurrentSensor.PHASE_B_REALval ;
    User_Debug.Ic = CurrentSensor.PHASE_C_REALval ;

    // 母线电压转换：考虑电压传感器增益
    VoltageSensor.VBUS_REALval = (VoltageSensor.VBUS_ADCval * 3.0f / 4095.0f) * VOLTAGE_SENSOR_GAIN;
}



void SMObserver_Calculate()
{
    // ===================== 1. 电机参数 =====================
    #define inv_Ld      9523.8f  // (1.0f / Ld)   // 电感倒数，全乘法
    #define Tsc         DREVER_LOOP_PERIOD_s

    // ===================== 2. 输入变量 =====================
    float Ualpha_old = User_Debug.UalphaOld;
    float Ubeta_old  = User_Debug.UbetaOld;
    float ialpha     = CurrentSensor.Current_alpha;
    float ibeta      = CurrentSensor.Current_beta;

    // ===================== 3. 静态历史变量 =====================
    static float ialpha_est_old = 0.0f;
    static float Ealpha_est_old = 0.0f;
    static float ibeta_est_old  = 0.0f;
    static float Ebeta_est_old  = 0.0f;
    static float Ealpha_est_LPF = 0.0f;
    static float Ebeta_est_LPF  = 0.0f;

    // 中间变量
    float ialpha_dot, ibeta_dot;
    float ialpha_est, ibeta_est;
    float sat_erro_ialpha, sat_erro_ibeta;
    float Ealpha_est_temp, Ebeta_est_temp;
    float theta_est;

    // ===================== 4. 电流微分（全乘法） =====================
    ialpha_dot = (-Rs * ialpha_est_old) * inv_Ld + Ualpha_old * inv_Ld - Ealpha_est_old * inv_Ld;
    ibeta_dot  = (-Rs * ibeta_est_old) * inv_Ld + Ubeta_old  * inv_Ld - Ebeta_est_old  * inv_Ld;

    // ===================== 5. 电流积分 =====================
    ialpha_est = ialpha_est_old + ialpha_dot * Tsc;
    ibeta_est  = ibeta_est_old  + ibeta_dot  * Tsc;

    // ===================== 6. 滑模符号函数 =====================
    sat_erro_ialpha = (ialpha_est - ialpha) > 0 ? 1.0f : ((ialpha_est - ialpha) < 0 ? -1.0f : 0.0f);
    sat_erro_ibeta  = (ibeta_est  - ibeta)  > 0 ? 1.0f : ((ibeta_est  - ibeta)  < 0 ? -1.0f : 0.0f);

    // ===================== 7. 反电动势计算 =====================
    Ealpha_est_temp = User_Debug.Kslide * sat_erro_ialpha;
    Ebeta_est_temp  = User_Debug.Kslide * sat_erro_ibeta;

    // ===================== 8. 极简低通滤波（纯乘法，无除法！） =====================
    float tau = Tsc * User_Debug.SMO_wc;
    float inv_den = 1.0f / (1.0f + tau);  // 只算1次倒数，后续全乘法
    float lpf_coef_old = 1.0f * inv_den;
    float lpf_coef_new = tau * inv_den;

    // 纯乘法滤波，极简！
    Ealpha_est_LPF = (Ealpha_est_LPF * lpf_coef_old) + (Ealpha_est_temp * lpf_coef_new);
    Ebeta_est_LPF  = (Ebeta_est_LPF  * lpf_coef_old) + (Ebeta_est_temp  * lpf_coef_new);

    // ===================== 9. 更新历史值 =====================
    ialpha_est_old = ialpha_est;
    ibeta_est_old  = ibeta_est;
    Ealpha_est_old = Ealpha_est_LPF;
    Ebeta_est_old  = Ebeta_est_LPF;

    // ===================== 10. 角度计算 =====================
    theta_est = atan2f(-Ealpha_est_LPF, Ebeta_est_LPF);
    if (theta_est <= 0.0f) theta_est += 2.0f * PI;

    // ===================== 11. 输出 =====================
    User_Debug.theta_est = theta_est;
}


/**
 * @brief  速度计算与滤波处理
 * @note   每500us（10个中断周期）计算一次速度，包含编码器溢出处理和一阶低通滤波
 */
static void SpeedCalculation(void)
{
    // 速度环计数递增，达到分频系数时计算速度
    User_Debug.count_speedloop++;
    if (User_Debug.count_speedloop >= SPEED_LOOP_DIV) {
        User_Debug.count_speedloop = 0;

        // 读取当前编码器位置并计算增量（处理溢出）
        User_Debug.speed_pos = __HAL_TIM_GET_COUNTER(&htim3);
        User_Debug.delta_pos = User_Debug.speed_pos - User_Debug.speed_pos_k_1;
        if (User_Debug.delta_pos < 0) {
            // 编码器正向溢出补偿（从最大值到最小值）
            User_Debug.delta_pos += ENCODER_MAX_CNT;
        }

        // 计算速度并限幅
        // User_Debug.speed = User_Debug.delta_pos * 60.0f/10000.0f/0.0005f; 
        User_Debug.speed = User_Debug.delta_pos * 12.0f;  // 速度转换系数

        Limiting_float(&User_Debug.speed, Max_Speed_RPM, -Max_Speed_RPM);
    }

    // 更新上一次位置并进行速度低通滤波
    User_Debug.speed_pos_k_1 = User_Debug.speed_pos;
    User_Debug.speed_LPF = SPEED_LPF_ALPHA * User_Debug.speed_LPF + SPEED_LPF_BETA * User_Debug.speed;
}

/**
 * @brief  电流环公共处理逻辑
 * @note   包含Park变换、电流环PI参数设置、电流调节、逆Park变换
 */
static void CurrentLoopCommonProcess(void)
{
    // Park变换：将αβ坐标系电流转换为dq坐标系
    Park(&CurrentSensor.Current_d, &CurrentSensor.Current_q,
         CurrentSensor.Current_alpha, CurrentSensor.Current_beta,
         PosSensor.eleAngle_sinVal, PosSensor.eleAngle_cosVal);

    // 保存反馈电流用于调试
    User_Debug.Id_fed = CurrentSensor.Current_d;
    User_Debug.Iq_fed = CurrentSensor.Current_q;

    // 电流环PI调节器参数计算（基于电感L、电阻R和控制周期）此时中断周期为50us；
    CurrLoop.Pid_Id_Kp = Ld / 3.0f / 0.00005f;  // d轴比例系数
    CurrLoop.Pid_Id_Ki = Rs / 3.0f / 0.00005f;  // d轴积分系数
    CurrLoop.Pid_Iq_Kp = Lq / 3.0f / 0.00005f;  // q轴比例系数
    CurrLoop.Pid_Iq_Ki = Rs / 3.0f / 0.00005f;  // q轴积分系数

    // 电流环PI调节（输入给定与反馈，输出电压指令）
    CurrentController(User_Debug.Id_ref, User_Debug.Iq_ref,
                      CurrentSensor.Current_d, CurrentSensor.Current_q);

    // 逆Park变换：将dq坐标系电压指令转换为αβ坐标系
    Inv_Park(&CurrLoop.Voltage_alpha_ref, &CurrLoop.Voltage_beta_ref,
             CurrLoop.Voltage_d_ref, CurrLoop.Voltage_q_ref,
             PosSensor.eleAngle_sinVal, PosSensor.eleAngle_cosVal);

    User_Debug.UalphaOld = CurrLoop.Voltage_alpha_ref;
    User_Debug.UbetaOld =  CurrLoop.Voltage_beta_ref;
}

/**
 * @brief  开环VF控制逻辑处理
 * @note   生成正弦电压矢量，无反馈调节，适用于电机初步测试
 */
static void OpenLoopControlProcess(void)
{
    // 角度增量生成（循环三角波，范围[-π, π]）
    User_Debug.counte -= User_Debug.incre_Vf / 1000.0f;
    if (User_Debug.counte > ANGLE_MAX) {
        User_Debug.counte = ANGLE_MIN;
    }
    // 计算正弦、余弦值用于电压矢量生成
    User_Debug.etheta = User_Debug.counte;
    User_Debug.alpha = arm_sin_f32(User_Debug.etheta);  // α轴电压分量
    User_Debug.beta = arm_cos_f32(User_Debug.etheta);   // β轴电压分量

    // 设置电压指令（开环模式直接给定电压）
    CurrLoop.Voltage_alpha_ref = User_Debug.alpha * User_Debug.Amp_VF;
    CurrLoop.Voltage_beta_ref = User_Debug.beta *  User_Debug.Amp_VF;

    // 保存当前编码器位置用于调试
    User_Debug.pos = __HAL_TIM_GET_COUNTER(&htim3);

    // 开环模式下清除电流环积分项，避免累积误差
    CurrLoop.Id_err_sum = 0;
    CurrLoop.Iq_err_sum = 0;

	// 计算速度
    SpeedCalculation();
}
/**
 * @brief  电流闭环IF控制逻辑处理
 * @note   基于给定电流指令进行闭环调节，包含角度生成和电流环控制
 */
static void CurrentLoopControlProcess(void)
{
    // 角度增量生成（同开环模式，范围[-π, π]），与速度匹配；
    User_Debug.counte += User_Debug.incre_If / 1000.0f;
    if (User_Debug.counte > ANGLE_MAX) {
        User_Debug.counte = ANGLE_MIN;
    }
    // 更新坐标变换的余弦值和正弦值；  
    User_Debug.etheta = User_Debug.counte;
    User_Debug.pos = __HAL_TIM_GET_COUNTER(&htim3);  // 保存编码器位置
    PosSensor.eleAngle_sinVal = arm_sin_f32(User_Debug.etheta);
    PosSensor.eleAngle_cosVal = arm_cos_f32(User_Debug.etheta);

    // 设定 I/F 电流大小，传递至电流环公共处理逻辑；；
    User_Debug.Id_ref = User_Debug.Amp_If;
   
    // 调用电流环公共处理逻辑（坐标变换与调节）
    CurrentLoopCommonProcess();

    // 计算速度
    SpeedCalculation();
}

/**
 * @brief  速度闭环控制逻辑处理
 * @note   包含速度环调节、零位校准（前2秒自动执行）、电流环级联控制
 * @note   基于50us中断计数器实现自动切换，移除ZeroFlag标志位
 * @note   电流渐变逻辑：0~1秒线性加到5A，1~2秒保持5A，总流程2秒
 * @note   50us/次中断 → 1秒=20000次，2秒=40000次
 * @note   关键修改：转速控制与转速计算频率同步（均为250us执行一次）
 */
static void SpeedLoopControlProcess(void)
{
    // ************************* 计数器与电流配置（基于50us中断，总流程2秒） *************************
    #define CALIB_TOTAL_CNT     40000  // 2秒对应的总中断次数：2000000us / 50us = 40000次
    #define CALIB_RISE_CNT      20000  // 1秒对应的中断次数：1000000us / 50us = 20000次（电流上升阶段）
    #define CALIB_TARGET_ID     5.0f   // 零位校准目标d轴电流（5A）
    static uint32_t calib_cnt = 0;     // 静态计数器：累加50us中断次数
    static uint8_t calib_finished = 0; // 静态标记：是否完成2秒零位校准（完成后永久进入正常模式）
    float current_Id_ref = 0.0f;       // 临时变量：存储渐变后的d轴电流值

    // 第一步：执行速度计算（保留原有分频逻辑，完成计数和有效速度更新）
    SpeedCalculation();

    // ************************* 关键修改：转速控制与转速计算频率同步 *************************
    // 仅当转速计算完成有效更新（count_speedloop被重置为0）时，才执行速度环控制
    uint8_t speed_calc_valid = (User_Debug.count_speedloop == 0) ? 1 : 0;
    
    if (speed_calc_valid) {
        // 速度环PI调节参数配置（仅在有效速度计算后更新，与计算频率同步）
        SpdLoop.Pid_Kp = User_Debug.speedKp;  // 速度环比例系数
        SpdLoop.Pid_Ki = User_Debug.speedKi;  // 速度环积分系数
        SpeedController(User_Debug.speedref, User_Debug.speed_LPF);
    }
    // 未完成有效速度计算时，跳过速度环调节，保持上一次的控制输出（避免无效波动）
    // *****************************************************************************************

    // ************************* 计数器累加式2秒自动切换 + 电流渐变逻辑 *************************
    if (calib_finished == 0)
    {
        // 未完成校准：累加计数器（每次50us中断进入此函数，计数器+1）
        calib_cnt++;

        // 判断计数器是否未达到2秒对应的总阈值（40000次）
        if (calib_cnt < CALIB_TOTAL_CNT)
        {
            // ************************* 电流渐变核心逻辑（两阶段） *************************
            if (calib_cnt <= CALIB_RISE_CNT)
            {
                // 阶段1：0~1秒（0~20000次）→ 线性递增到5A
                // 电流计算公式：(当前中断次数 / 上升阶段总次数) × 目标电流（保证线性平滑渐变）
                current_Id_ref = (float)calib_cnt / (float)CALIB_RISE_CNT * CALIB_TARGET_ID;
            }
            else
            {
                // 阶段2：1~2秒（20000~40000次）→ 保持5A不变
                current_Id_ref = CALIB_TARGET_ID;
            }

            // 执行零位校准逻辑（使用渐变后的d轴电流，无突变）
            User_Debug.Id_ref = current_Id_ref;  // 渐变后的d轴电流
            User_Debug.Iq_ref = 0.0f;            // q轴电流给定（零转矩，保持不变）

            // 强制零位置，清除角度累积
            User_Debug.etheta = 0.0f;
            PosSensor.eleAngle_sinVal = arm_sin_f32(User_Debug.etheta);
            PosSensor.eleAngle_cosVal = arm_cos_f32(User_Debug.etheta);

            // 编码器与位置归零，清除速度环积分项
            __HAL_TIM_SET_COUNTER(&htim3, 0);
            SpdLoop.Err_sum = 0;
            g_encoder.output.rotor_pos = 0;
            g_encoder.output.encoder_pos = 0;
        }
        else
        {
            // 达到2秒：标记校准完成，后续永久进入正常模式（计数器不再累加）
            calib_finished = 1;
        }
    }

    // ************************* 正常模式逻辑（2秒后自动进入，永久生效） *************************
    if (calib_finished == 1)
    {
        // 正常模式：速度环输出作为Q轴电流指令，d轴零电流（最大转矩控制）
        User_Debug.Iq_ref = SpdLoop.Output;
        User_Debug.Id_ref = 0.0f;

        // 根据编码器位置计算电角度
        User_Debug.pos = __HAL_TIM_GET_COUNTER(&htim3);
        User_Debug.etheta = User_Debug.pos * PI * 2.0f * 5.0f * 0.0001f;  // 角度转换公式

        User_Debug.ethetaAct = fmodf(User_Debug.etheta, 2*PI); // 先对2π取余，得到[-2π, 2π)范围
        if (User_Debug.ethetaAct < 0.0f) {               // 若为负数，加2π转为正数
            User_Debug.ethetaAct += 2*PI;
        }

        if(User_Debug.SensorlessFlag >0.5f)
        {
            User_Debug.etheta = User_Debug.theta_est;  // 角度转换公式
        }
        else
        {
            
            User_Debug.etheta = User_Debug.pos * PI * 2.0f * 5.0f * 0.0001f;  // 角度转换公式
        }

        PosSensor.eleAngle_sinVal = arm_sin_f32(User_Debug.etheta);
        PosSensor.eleAngle_cosVal = arm_cos_f32(User_Debug.etheta);


    }

    // 调用电流环公共处理逻辑（坐标变换与调节）
    CurrentLoopCommonProcess();
}

/**
 * @brief  ADC注入转换完成回调函数
 * @param  hadc: ADC句柄
 * @note   电机控制主循环入口，每50us执行一次，包含各模式控制逻辑
 */
void HAL_ADCEx_InjectedConvCpltCallback(ADC_HandleTypeDef *hadc)
{
    if (hadc == &hadc1) {  // 仅处理ADC1的注入转换完成事件
        // 调试引脚翻转（用于观测中断周期）
        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);

        // 更新编码器参数并初始化周期变量
        Encoder_Param_Update(&g_encoder);
        static uint32_t loopcut = 0, timcut = 0;  // 循环计数变量
        timcut++;
        loopcut++;

        // 获取位置基础信息并更新编码器位置
        Get_PosInf();
        Encoder_Get_Pos(&g_encoder);  // 仅保留一次调用，去除冗余

        // 电流电压采样与Clark变换（αβ坐标系转换）
        CurrentVoltageSampling();
        Clarke(&CurrentSensor.Current_alpha, &CurrentSensor.Current_beta,
               CurrentSensor.PHASE_A_REALval, CurrentSensor.PHASE_B_REALval);

        // 根据控制模式执行对应逻辑
        switch ((ControlMode_e)User_Debug.ControlFlag) {
            case CTRL_MODE_OPEN_LOOP:
                OpenLoopControlProcess();
                break;
            case CTRL_MODE_CURRENT_LOOP:
                CurrentLoopControlProcess();
                break;
            case CTRL_MODE_SPEED_LOOP:
                SMObserver_Calculate();
                SpeedLoopControlProcess();
                break;
            default:
                // 无效模式：可添加故障处理逻辑
                break;
        }

        // 空间矢量调制（将αβ电压指令转换为PWM信号）
       // SpaceVectorModulation(CurrLoop.Voltage_alpha_ref, CurrLoop.Voltage_beta_ref);
        calcPwmDutyZeroInjectByAlphaBeta(CurrLoop.Voltage_alpha_ref, CurrLoop.Voltage_beta_ref);
        // DEBUG_FLOATS(2,(float)(User_Debug.speed_LPF),(float)(User_Debug.Ia),(float)(User_Debug.Iq_fed),(float)(User_Debug.pos));
         timcut++;
         if  (timcut>20) // 对应1ms发一次
         {
            DEBUG_FLOATS(4,(float)(User_Debug.Ia),(float)(User_Debug.Id_fed),(float)(User_Debug.speed_LPF),(float)(User_Debug.Iq_fed));
            timcut = 0;
        }
    }
}