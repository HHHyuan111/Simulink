/**
  ******************************************************************************
  * File Name          : debug.h
  * Author             : Song2333
  * Description        : This file provides code for debug.
  ******************************************************************************
  * @attention
  *     
  * 
  *             
  *     
  *     
  *****************************ACTION*******************************************
  */

  /* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __USER_DEBUG_H__
#define __USER_DEBUG_H__

/* Private includes ----------------------------------------------------------*/
/* CODE BEGIN Includes */
#include "main.h"
#include "stdio.h"
#include "usart.h"
#include "stdlib.h"
#include "string.h"
/* CODE END Includes */

/* Private typedef -----------------------------------------------------------*/


#define DEBUG_UART_HANDLER     hlpuart1
#define DEBUG_BUFSIZE          256

#define DIV10(x)    (((int64_t)x*0x66666667L)>>34)

int32_t int32_to_char(int32_t x, char *str);

typedef struct
{
	float *fdata;
	unsigned char tail[4];

}FRAME;

typedef struct
{
	uint32_t tim;
	float counte;
  uint32_t count_speedloop;
	uint32_t flag;
	uint16_t pos_rx;
	uint16_t pos_14bit;
	float alpha;
	float beta;
  float PWMA;
  float PWMB;
  float PWMC;
  float incre_Vf;
  float Amp_VF;
  float incre_If;
  float Amp_If;
  float Id_ref;
  float Id_fed;
  float Iq_ref;
  float Iq_fed;
  float ControlFlag;
  uint32_t speed_pos;
  uint32_t speed_pos_k_1;
  uint32_t pos;
  uint32_t pos_k_1;
  uint32_t ZeroFlag;
  int delta_pos;
  float speed;
  float speed_LPF;
  float etheta;
  float etheta2pi;
  float speedref;
  float speedKp;
  float speedKi;
  float Ia;
  float Ib;
  float Ic;
  float P1;
  float I1;
  float D1;
  float UalphaOld;
  float UbetaOld;
  float theta_est;
  float Speed_est;
  float Kslide;
  float SMO_wc;
  float SensorlessFlag;
  float ethetaAct;

}DEBUG_TypeDef;

extern DEBUG_TypeDef User_Debug;


extern uint8_t debug_buffer[DEBUG_BUFSIZE];

#define DEBUG(...) {\
	int len = 0;\
	len = 0;\
	len =snprintf((char *)debug_buffer,64,__VA_ARGS__);\
	if(len>0){\
		HAL_UART_Transmit_DMA(&DEBUG_UART_HANDLER, (uint8_t *)debug_buffer, len);\
	}\
}

#define DEBUG_FLOATS(n, ...) {\
    float data[n + 1];\
    float temp_data[] = {__VA_ARGS__};\
    memcpy(data, temp_data, (n) * sizeof(float));\
    uint8_t tail[] = {0x00, 0x00, 0x80, 0x7f};\
    memcpy((uint8_t *)(data + n), tail, 4);\
    int len = (n) * sizeof(float) + 4;\
    HAL_UART_Transmit_DMA(&DEBUG_UART_HANDLER, (uint8_t *)data, len);\
}

//#define DEBUG(...) {\
//static int ppplen = 0;\
//ppplen +=int32_to_char(__VA_ARGS__,(char *)(debug_buffer+ppplen));\
//if(ppplen>100){\
//	HAL_UART_Transmit_DMA(&DEBUG_UART_HANDLER, (uint8_t *)debug_buffer, ppplen);\
//	ppplen = 0;\
//}\
//}

//HAL_UART_Transmit_DMA(&DEBUG_UART_HANDLER, (uint8_t *)debug_buffer, len)
#endif
/************************ (C) COPYRIGHT ACTION *****END OF FILE*****************/