#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <SoftwareSerial.h>

// --- 硬件定义 ---
#define BT_RX 8
#define BT_TX 7
#define RST_PIN 9
#define SS_PIN 10
#define SERVO_PIN 6
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

// --- 全局对象 ---
SoftwareSerial BT(BT_RX, BT_TX);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
MFRC522 mfrc522(SS_PIN, RST_PIN);
Servo doorLock;

// --- 变量 ---
byte authorizedUID[4] = {0x93, 0x4F, 0x22, 0xF8};
bool doorState = false;
unsigned long doorOpenTime = 0;
unsigned long lastRfidCheck = 0;
// 减少全局变量，能省一点是一点

void setup() {
  // 1. 初始化串口
  Serial.begin(9600);
  BT.begin(9600);
  
  // 2. 初始化 OLED (最耗内存的部分)
  // 如果这里失败，说明内存真的不够了
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("OLED Fail")); // 串口提示
    // 如果屏幕不亮，代码依然会继续运行蓝牙和RFID
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0,0);
  display.println(F("System Init..."));
  display.display();

  // 3. 舵机
  doorLock.attach(SERVO_PIN);
  doorLock.write(0);

  // 4. SPI & RFID
  SPI.begin();
  mfrc522.PCD_Init();
  delay(100);
  mfrc522.PCD_SetAntennaGain(mfrc522.RxGain_max);

  Serial.println(F("Ready"));
  drawUI("READY");
}

void loop() {
  // --- 1. 蓝牙处理 (非阻塞模式) ---
  if (BT.available()) {
    char cmd = BT.read(); // 只读一个字符，绝不等待
    Serial.print(F("BT:")); Serial.println(cmd);
    
    if (cmd == '1') { // 手机发送字符 '1' 开门
      openDoor();
      BT.print('K'); // 回复 'K' 代表 OK
    } 
    else if (cmd == '0') { // 手机发送字符 '0' 关门
      closeDoor();
      BT.print('K');
    }
    else if (cmd == '?') { // 查询状态
      BT.print(doorState ? 'O' : 'C'); // O=Open, C=Closed
    }
  }

  // --- 2. 自动关门 ---
  if (doorState && (millis() - doorOpenTime > 3000)) {
    closeDoor();
  }

  // --- 3. RFID 处理 (每50ms检测一次，防止刷屏) ---
  if (millis() - lastRfidCheck > 50) {
    lastRfidCheck = millis();
    handleRFID();
  }
}

void handleRFID() {
  // 必须先检测是否有卡，否则不要浪费时间读数据
  if (!mfrc522.PICC_IsNewCardPresent()) return;
  if (!mfrc522.PICC_ReadCardSerial()) return;

  // 验证
  if (isAuthorized()) {
    Serial.println(F("Auth OK"));
    drawUI("CARD: OK");
    openDoor();
  } else {
    Serial.println(F("Auth Fail"));
    drawUI("CARD: DENY");
    delay(500); // 拒绝时稍微停顿显示一下
    drawUI("READY");
  }

  // 停止加密，准备下一次
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();
}

bool isAuthorized() {
  if (mfrc522.uid.size != 4) return false;
  for (byte i = 0; i < 4; i++) {
    if (mfrc522.uid.uidByte[i] != authorizedUID[i]) return false;
  }
  return true;
}

void openDoor() {
  if(doorState) return;
  doorLock.write(90);
  doorState = true;
  doorOpenTime = millis();
  drawUI("OPENED");
  Serial.println(F("Door Open"));
}

void closeDoor() {
  if(!doorState) return;
  doorLock.write(0);
  doorState = false;
  drawUI("READY");
  Serial.println(F("Door Closed"));
}

// 极简UI函数，避免复杂的局部变量
void drawUI(const char* status) {
  display.clearDisplay();
  
  // 标题
  display.setTextSize(1);
  display.setCursor(0,0);
  display.print(F("BLE+RFID Door"));

  // 状态大字
  display.setTextSize(2);
  display.setCursor(0, 25);
  display.print(status);

  // 底部提示
  display.setTextSize(1);
  display.setCursor(0, 55);
  if(doorState) display.print(F("State: UNLOCKED"));
  else display.print(F("State: LOCKED"));

  display.display();
}