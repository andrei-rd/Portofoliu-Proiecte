# Statie Meteo Interactiva cu Arduino 🌤️

Acest proiect reprezinta o statie meteo inteligenta construita pe platforma Arduino Uno, dezvoltata folosind **PlatformIO**. Proiectul citeste date de mediu in timp real, afiseaza animatii dinamice pe un ecran OLED si ofera un dashboard live prin Serial Monitor.

## Functionalitati Principale
* **Afisaj OLED Dinamic:** Animatiile grafice se schimba in timp real in functie de temperatura (fulg de nea, soare, valuri de caldura).
* **Monitorizare Live:** Datele sunt procesate doar cand exista modificari (pentru eficienta) si sunt transmise curat catre Serial Monitor prin rescrierea randului (`\r`), fara a inunda consola.
* **Indicator Vizual RGB:** Un LED RGB isi schimba culoarea automat (Albastru = Frig, Verde = Confortabil, Rosu = Cald).
* **Optimizare Memorie:** Codul este optimizat pentru memoria RAM limitata a placii Arduino (2KB), folosind macroul `F()` pentru stringuri si eliminand variabilele globale inutile care ar fi intrat in conflict cu bufferul ecranului OLED.

## Componente Hardware
* Placa de dezvoltare compatibila Arduino Uno R3
* Ecran OLED SSD1306 128x64 (Comunicare I2C)
* Modul Senzor Temperatura si Umiditate HW-507 (DHT11)
* Modul Senzor Lumina HW-486 (LDR / Fotoresistor)
* Modul LED RGB HW-478

## Schema de Conectare

| Modul | Pini Modul | Conexiune Arduino Uno |
| :--- | :--- | :--- |
| **OLED SSD1306** | VCC, GND, SDA, SCL | 5V, GND, A4, A5 |
| **HW-507 (DHT11)** | VCC, GND, Data | 5V, GND, D2 |
| **HW-486 (Lumina)** | VCC, GND, AO | 5V, GND, A1 |
| **HW-478 (LED RGB)**| GND, R, G, B | GND, D9, D10, D11 (Pini PWM) |

## Cum rulezi proiectul
1. Cloneaza acest repository.
2. Deschide folderul in VS Code folosind extensia **PlatformIO**.
3. PlatformIO va descarca automat bibliotecile necesare (definite in `platformio.ini`): *Adafruit GFX, Adafruit SSD1306, DHT sensor library*.
4. Compileaza si incarca codul pe placa (`Upload`).
5. Deschide Serial Monitor la 9600 baud rate.