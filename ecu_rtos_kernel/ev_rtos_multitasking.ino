/**
 * @file ev_rtos_multitasking.ino
 * @brief Real-Time Operating System (FreeRTOS) Multitasking Engine for EV ECUs.
 * @note Simulates real-time task scheduling, task priorities, and shared resource protection.
 */

#include <Arduino_FreeRTOS.h> // Include standard FreeRTOS kernel layers

// Define Task Handles for system tracking
TaskHandle_t xSensorTaskHandle  = NULL;
TaskHandle_t xMotorTaskHandle   = NULL;
TaskHandle_t xDisplayTaskHandle = NULL;

// Shared Global Variables (Simulating Vehicle Data Bus)
volatile float global_temperature = 25.0;
volatile float global_motor_speed  = 0.0;
volatile bool  global_system_fault = false;

// ==============================================================================
// System Setup Layer
// ==============================================================================
void setup() {
  // Initialize Serial Communication for Telemetry Logging
  Serial.begin(115200);
  while (!Serial); // Wait for terminal connection
  
  Serial.println(F("=================================================="));
  Serial.println(F("   Booting FreeRTOS EV Control Kernel...         "));
  Serial.println(F("=================================================="));

  // --------------------------------------------------------------------------
  // Task Creation Matrix (Task Function, Name, Stack Size, Parameter, Priority, Handle)
  // --------------------------------------------------------------------------
  xTaskCreate(vSensorSafetyTask, "Sensor_Safety", 128, NULL, 3, &xSensorTaskHandle);
  xTaskCreate(vMotorControlTask, "Motor_Control", 128, NULL, 2, &xMotorTaskHandle);
  xTaskCreate(vDisplayTelemetryTask, "Display_Refresh", 128, NULL, 1, &xDisplayTaskHandle);
}

void loop() {
  // Empty! FreeRTOS kernel has bypassed standard sequential looping structure.
}

// ==============================================================================
// 1. High-Priority Task: Sensor Ingestion & Critical Safety Diagnostics
// ==============================================================================
void vSensorSafetyTask(void *pvParameters) {
  (void) pvParameters;
  TickType_t xLastWakeTime = xTaskGetTickCount();
  const TickType_t xFrequency = pdMS_TO_TICKS(50); // Execution constraint: 50ms

  for (;;) {
    if (!global_system_fault) {
      global_temperature += 0.8; 
    }

    if (global_temperature > 80.0 && !global_system_fault) {
      global_system_fault = true;
      Serial.println(F("\n[RTOS CRITICAL] Safety Threshold Breached (>80C)! Triggering Task Preemption..."));
      vTaskPrioritySet(xMotorTaskHandle, 0); // Force demote motor processing to idle tier
    }

    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}

// ==============================================================================
// 2. Medium-Priority Task: Core Powertrain / Motor Control Calculations
// ==============================================================================
void vMotorControlTask(void *pvParameters) {
  (void) pvParameters;
  TickType_t xLastWakeTime = xTaskGetTickCount();
  const TickType_t xFrequency = pdMS_TO_TICKS(100); // Loops every 100ms

  for (;;) {
    if (global_system_fault) {
      global_motor_speed = 0.0; // Force immediate torque suppression
      Serial.println(F("[RTOS SAFE-STATE] Motor Power Isolation Confirmed. Transitioned to Safe-State."));
      vTaskDelete(NULL); // Terminate this task completely
    } else {
      if (global_motor_speed < 120.0) {
        global_motor_speed += 5.5; 
      }
    }

    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}

// ==============================================================================
// 3. Low-Priority Task: EV Digital Dashboard UI Display Telemetry
// ==============================================================================
void vDisplayTelemetryTask(void *pvParameters) {
  (void) pvParameters;
  TickType_t xLastWakeTime = xTaskGetTickCount();
  const TickType_t xFrequency = pdMS_TO_TICKS(500); // Periodic telemetry broadcast: 500ms

  for (;;) {
    Serial.println(F("---------------------------------------------"));
    Serial.print(F("[DASHBOARD] Motor Temp: ")); Serial.print(global_temperature, 1); Serial.print(F(" C | "));
    Serial.print(F("Velocity: ")); Serial.print(global_motor_speed, 1); Serial.println(F(" RPM"));
    Serial.print(F("[SYSTEM STATUS] Code: "));
    if (global_system_fault) {
      Serial.println(F("🚨 FAULT MODALITY POWER ISOLATION REDALERT"));
    } else {
      Serial.println(F("✅ NOMINAL RUNNING PROPULSION ACTIVE"));
    }

    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}
