# Interactive Weather Station with Arduino Uno R3 🌤️

![Weather Station Hero](images/20260328_154928.jpg)

This project represents a smart weather station built on the Arduino Uno platform, developed using **PlatformIO**. The system reads real-time environmental data, displays dynamic animations on an OLED screen, and provides a live, non-blocking dashboard via the Serial Monitor.

## Key Features
* **Dynamic OLED Display:** Graphic animations change in real-time based on the current temperature (e.g., snowflake, sun, heatwaves) and light level (rain cloud in the dark).
* **Live Monitoring:** Sensor data is processed only when changes occur and is transmitted cleanly to the Serial Monitor using carriage return line updates, preventing console flooding.
* **RGB Visual Indicator:** An RGB LED automatically changes color to reflect the environment (Blue = Cold, Green = Comfortable, Red = Hot).
* **Memory Optimization:** The codebase is heavily optimized for the Arduino's limited RAM (2KB) by utilizing the `F()` macro for strings and managing scope to prevent OLED buffer overflow.

---

## User Interface (UI)

The following image shows a close-up of the OLED screen, displaying the current sensor readings (Temperature, Humidity, Light Intensity) alongside the active dynamic animation:

![OLED UI Close-up](images/20260328_155010.jpg)

---

## Hardware Components & Wiring

The station is fully assembled on a breadboard. The picture below illustrates the component layout and wiring (top-down view):

![Wiring Top-Down](images/20260328_155033.jpg)

| Module | Module Pins | Arduino Uno Connection | Role |
| :--- | :--- | :--- | :--- |
| **OLED SSD1306** | VCC, GND, SDA, SCL | 5V, GND, A4, A5 | Graphic display (I2C) |
| **HW-507 (DHT11)** | VCC, GND, Data | 5V, GND, D2 | Temperature & Humidity sensor |
| **HW-486 (LDR)** | VCC, GND, AO | 5V, GND, A1 | Light Intensity sensor |
| **HW-478 (RGB LED)**| GND, R, G, B | GND, D9, D10, D11 (PWM Pins) | Environmental visual indicator |

---

## How to Run the Project
1. Clone this repository to your local machine.
2. Open the project folder in **VS Code** with the **PlatformIO** extension installed.
3. PlatformIO will automatically fetch and install the required dependencies defined in `platformio.ini` (*Adafruit GFX, Adafruit SSD1306, DHT sensor library*).
4. Compile and upload the firmware to your Arduino Uno board.
5. Open the Serial Monitor and set the baud rate to **9600** to view the live dashboard.
