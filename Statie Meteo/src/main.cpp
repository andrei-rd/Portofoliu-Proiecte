#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

#define DHTPIN 2
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

#define LDR_PIN A1
#define RED_PIN 9
#define GREEN_PIN 10
#define BLUE_PIN 11

int frame = 0;

void setup() {
  Serial.begin(9600);
  dht.begin();
  
  pinMode(RED_PIN, OUTPUT);
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);

  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
    Serial.println(F("Eroare OLED!"));
    for(;;); 
  }
  
  display.clearDisplay();
  display.display(); 
  display.setTextColor(WHITE);

  Serial.println(); 
  Serial.println(F("=== Statia Meteo a pornit ==="));
}

void setColor(int red, int green, int blue) {
  analogWrite(RED_PIN, red);
  analogWrite(GREEN_PIN, green);
  analogWrite(BLUE_PIN, blue);
}

void drawWeatherAnimation(float temp, int x_pos, int y_pos, int frame_num) {
  display.fillRect(x_pos, y_pos, 40, 40, BLACK);

  if (temp < 20.0) {
    int center_x = x_pos + 20;
    int center_y = y_pos + 20;
    int size = 15;
    float angle_offset = frame_num * 0.2;

    for(int i = 0; i < 4; i++) {
        float angle = (i * PI / 4.0) + angle_offset;
        int x1 = center_x + cos(angle) * size;
        int y1 = center_y + sin(angle) * size;
        int x2 = center_x - cos(angle) * size;
        int y2 = center_y - sin(angle) * size;
        display.drawLine(x1, y1, x2, y2, WHITE);
    }
    display.drawCircle(center_x, center_y, 4, WHITE);
  
  } else if (temp >= 20.0 && temp <= 26.0) {
    int center_x = x_pos + 20;
    int center_y = y_pos + 20;
    int base_radius = 10;

    display.fillCircle(center_x, center_y, base_radius, WHITE);
    
    int num_rays = 8;
    int ray_length = 8;
    for(int i = 0; i < num_rays; i++) {
        float angle = i * (2 * PI / num_rays);
        int start_x = center_x + cos(angle) * (base_radius + 2);
        int start_y = center_y + sin(angle) * (base_radius + 2);
        int end_x = center_x + cos(angle) * (base_radius + ray_length + (frame_num % 3)); 
        int end_y = center_y + sin(angle) * (base_radius + ray_length + (frame_num % 3));
        display.drawLine(start_x, start_y, end_x, end_y, WHITE);
    }

  } else {
    int start_x = x_pos + 5;
    int start_y = y_pos + 5;
    
    for(int i = 0; i < 3; i++) {
        int current_x = start_x + (i * 12);
        int y_offset = (frame_num * 3) % 15; 
        
        for(int py = 0; py < 25; py++) {
            int px = current_x + sin((py + frame_num*2) * 0.3) * 3;
            int final_y = start_y + py - y_offset;
            
            if(final_y > y_pos && final_y < (y_pos + 35)) {
                 display.drawPixel(px, final_y, WHITE);
            }
        }
    }
  }
}

void loop() {
  static unsigned long lastSensorRead = 0;
  
  static float umiditate = 0.0;
  static float temperatura = 0.0;
  static int intensitateLuminoasa = 0;

  static float old_umiditate = -99.0;
  static float old_temperatura = -99.0;
  static int old_intensitateLuminoasa = -99;

  if (millis() - lastSensorRead > 2000) {
      float h = dht.readHumidity();
      float t = dht.readTemperature();
      int nivelLuminaBrut = analogRead(LDR_PIN);
      
      intensitateLuminoasa = map(nivelLuminaBrut, 0, 1023, 0, 100); 

      if (!isnan(h) && !isnan(t)) {
          umiditate = h;
          temperatura = t;
          
          if (temperatura != old_temperatura || umiditate != old_umiditate || intensitateLuminoasa != old_intensitateLuminoasa) {
              Serial.print(F("\rTemp: ")); Serial.print(temperatura, 1);
              Serial.print(F(" C | Umiditate: ")); Serial.print(umiditate, 0);
              Serial.print(F(" % | Intensitate luminoasa: ")); Serial.print(intensitateLuminoasa);
              Serial.print(F(" %       ")); 
              
              old_temperatura = temperatura;
              old_umiditate = umiditate;
              old_intensitateLuminoasa = intensitateLuminoasa;
          }
      }

      if (temperatura < 20.0) {
        setColor(0, 0, 255);       
      } else if (temperatura >= 20.0 && temperatura <= 26.0) {
        setColor(0, 255, 0);       
      } else {
        setColor(255, 0, 0);       
      }
      lastSensorRead = millis();
  }

  display.clearDisplay();
  display.setTextSize(1);
  
  display.setCursor(25, 0);
  display.println(F("STATIE METEO")); 
  display.drawLine(0, 10, 128, 10, WHITE);
  
  display.setCursor(0, 18);
  display.print(F("Temp:  "));
  display.print(temperatura, 1); 
  display.print(F("C"));

  display.setCursor(0, 33);
  display.print(F("Umid:  "));
  display.print(umiditate, 0); 
  display.print(F("%"));

  display.setCursor(0, 48);
  display.print(F("Intens:"));
  display.print(intensitateLuminoasa);
  display.print(F("%"));

  drawWeatherAnimation(temperatura, 85, 18, frame);

  frame++;
  if(frame > 1000) frame = 0;

  display.display();
  delay(50); 
}