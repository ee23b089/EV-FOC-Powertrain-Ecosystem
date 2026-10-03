/**
 * @file ev_rtos_multitasking.ino
 * @brief Real-Time Operating System (FreeRTOS) Multitasking Engine with Mutex Locks.
 * @note Implements a Mutex to protect critical shared variables from data races.
 */

#include <Arduino_FreeRTOS.h> 
#include <semphr.h> // Required FreeRTOS header for Mutex/Semaphore structures

// Define Task Handles
TaskHandle_t xSensorTaskHandle  = NULL;
TaskHandle_t xMotorTaskHandle   = NULL;
TaskHandle_t xDisplayTaskHandle = NULL;

// Define the Mutex Handle
SemaphoreHandle_t xVehicleDataMutex = NULL;

// Shared Global Variables (Critical Resources Protected by Mutex)
volatile float global_temperature = 25.0;
volatile float global_motor_speed  = 0.0;
volatile bool  global_system_fault = false;

// ==============================================================================
// System Setup Layer
// ==============================================================================
void setup() {
  Serial.begin(115200);
  while (!Serial); 
  
  Serial.println(F("=================================================="));
  Serial.println(F("   Booting Secure FreeRTOS Kernel with Mutex...  "));
  Serial.println(F("=================================================="));

  // 1. Create the Mutex Lock before starting any concurrent tasks
  xVehicleDataMutex = xSemaphoreCreateMutex();

  if (xVehicleDataMutex != NULL) {
    Serial.println(F("[RTOS INIT] Mutex Lock created successfully."));
  } else {
    Serial.println(F("[RTOS FATAL] Failed to allocate Mutex Memory!"));
    while(1); // Halt system if safety primitive fails
  }

  // 2. Create the Task Matrix
  xTaskCreate(vSensorSafetyTask, "Sensor_Safety", 128, NULL, 3, &xSensorTaskHandle);
  xTaskCreate(vMotorControlTask, "Motor_Control", 128, NULL, 2, &xMotorTaskHandle);
  xTaskCreate(vDisplayTelemetryTask, "Display_Refresh", 128, NULL, 1, &xDisplayTaskHandle);
}

void loop() {
  // Empty! Bypassed by FreeRTOS scheduler kernel.
}

// ==============================================================================
// 1. High-Priority Task: Sensor Ingestion & Critical Safety Diagnostics
// ==============================================================================
void vSensorSafetyTask(void *pvParameters) {
  (void) pvParameters;
  TickType_t xLastWakeTime = xTaskGetTickCount();
  const TickType_t xFrequency = pdMS_TO_TICKS(50); // 50ms loop constraint

  for (;;) {
    // Attempt to acquire the Mutex Key. Wait up to 10 ticks if blocked.
    if (xSemaphoreTake(xVehicleDataMutex, 10) == pdTRUE) {
      // --- CRITICAL SECTION START ---
      if (!global_system_fault) {
        global_temperature += 0.8; 
      }

      if (global_temperature > 80.0 && !global_system_fault) {
        global_system_fault = true;
        Serial.println(F("\n[RTOS CRITICAL] Safety Breach! Mutex secured. Demoting Motor Priority..."));
        vTaskPrioritySet(xMotorTaskHandle, 0); 
      }
      // --- CRITICAL SECTION END ---
      
      xSemaphoreGive(xVehicleDataMutex); // Release key back to the pool instantly
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
  const TickType_t xFrequency = pdMS_TO_TICKS(100); // 100ms loop constraint

  for (;;) {
    // Acquire key before checking or modifying shared memory states
    if (xSemaphoreTake(xVehicleDataMutex, 10) == pdTRUE) {
      // --- CRITICAL SECTION START ---
      if (global_system_fault) {
        global_motor_speed = 0.0; 
        Serial.println(F("[RTOS SAFE-STATE] Motor speed isolated via Mutex protection loop."));
        xSemaphoreGive(xVehicleDataMutex); // Give back key before deleting task!
        vTaskDelete(NULL); 
      } else {
        if (global_motor_speed < 120.0) {
          global_motor_speed += 5.5; 
        }
      }
      // --- CRITICAL SECTION END ---
      
      xSemaphoreGive(xVehicleDataMutex); 
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
  const TickType_t xFrequency = pdMS_TO_TICKS(500); // 500ms loop constraint

  for (;;) {
    // Read parameters safely using Mutex protection to prevent reading corrupted partial half-writes
    if (xSemaphoreTake(xVehicleDataMutex, portMAX_DELAY) == pdTRUE) {
      Serial.println(F("---------------------------------------------"));
      Serial.print(F("[DASHBOARD] Motor Temp: ")); Serial.print(global_temperature, 1); Serial.print(F(" C | "));
      Serial.print(F("Velocity: ")); Serial.print(global_motor_speed, 1); Serial.println(F(" RPM"));
      Serial.print(F("[SYSTEM STATUS] Code: "));
      if (global_system_fault) {
        Serial.println(F("🚨 FAULT MODALITY MUTEX POWER ISOLATION ACTIVE"));
      } else {
        Serial.println(F("✅ NOMINAL RUNNING PROPULSION ACTIVE"));
      }
      
      xSemaphoreGive(xVehicleDataMutex); 
    }

    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}
