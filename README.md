
# Electric Machine Simulation Models

A collection of MATLAB-based simulation models and control algorithms for electrical machines.

This repository provides simulation resources for electrical machine modeling, control algorithm development, and academic research.

## 1. Projects

### 1.1 Asynchronous Motor FOC

**Directory:** `1_Asynchronous_Motor_FOC`

Field-Oriented Control (FOC) simulation project for
an asynchronous (induction) motor.

[View Project](./1_Asynchronous_Motor_FOC)

[Related Blog](https://zhuanlan.zhihu.com/p/589098477)

### 1.2 PMSM FOC

**Directory:** `2_PMSM_FOC_MATLAB/PMSM_FOC_SheeperXu`

Field-Oriented Control (FOC) simulation project for
a Permanent Magnet Synchronous Motor (PMSM).

[View Project](./2_PMSM_FOC_MATLAB/PMSM_FOC_SheeperXu)

[Related Blog](https://zhuanlan.zhihu.com/p/667769632)

### 1.3 Current PMSM model — MATLAB R2026a

**Current model:** [`modern/PMSM_FOC_R2026a.slx`](./modern/PMSM_FOC_R2026a.slx)

The current working version preserves the original FOC control blocks in a flat layout with nine aligned, equally sized regions. Legacy SPS dependencies have been replaced with ordinary Simulink blocks. It requires MATLAB R2026a and Simulink; parameters are embedded in the model workspace.

- [运行方法、验证结果与待修复问题](./modern/README.md)
- [当前模型全图](./modern/layout/flat_tidy.png)
- [逐模块解读](./review/learning/PMSM模型逐模块解读.md)
- [STM32G474 仿真开发计划](./review/learning/STM32G474仿真开发计划.md)
- [完整解读与开发计划（Word）](./review/learning/PMSM模型解读与STM32G474开发计划.docx)

This version is a runnable learning and development starting point. Motor parameters are demonstration values; STM32G474RET6 board and firmware behavior have not yet been calibrated or validated.

## 2. Software Requirements

- Current `modern/` model: MATLAB R2026a and Simulink (verified with R2026a Update 5).
- Original models: requirements depend on their original MATLAB release and toolboxes; see the project files.

## 3. Getting Started

1. Download or clone this repository.
2. Open MATLAB.
3. Navigate to the desired project directory.
4. Open the corresponding simulation model or main script.
5. Configure the required parameters and run the simulation.

Please refer to the project files for specific settings.

## 4. Repository Structure

    Electric-Machine-for-Sharing/
    |
    |-- 1_Asynchronous_Motor_FOC/
    |
    |-- 2_PMSM_FOC_MATLAB/
    |   |-- PMSM_FOC_SheeperXu/
    |
    |-- modern/               Current R2026a PMSM model and validation
    |
    |-- review/learning/      Model walkthrough and development plan
    |
    |-- README.md

## 5. Applications

These simulation models are intended for:

- Electrical machine research
- Motor control algorithm development
- MATLAB-based simulation and analysis
- Educational and academic use

## 6. Author

GitHub: [Sheeper-Xu](https://github.com/Sheeper-Xu)

Zhihu:[Sheeper-Xu](https://www.zhihu.com/people/xu-yi-yang-53-96/posts)

## 7. Notes

These models are shared for research and educational purposes. 
Please verify their suitability and accuracy before using them in other applications.
