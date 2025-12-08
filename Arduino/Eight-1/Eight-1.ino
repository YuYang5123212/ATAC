#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>
#include <SoftwareSerial.h>

// 引脚定义
#define RST_PIN 9
#define SS_PIN 10
#define SERVO_PIN 6
#define BT_TX_PIN 2
#define BT_RX_PIN 3

// 对象初始化
MFRC522 mfrc522(SS_PIN, RST_PIN);
Servo doorLock;
SoftwareSerial BTSerial(BT_TX_PIN, BT_RX_PIN); // RX, TX

// 授权的RFID卡UID
byte authorizedUID[4] = {0x63, 0x19, 0xE1, 0x11};

// 系统状态
bool doorState = false; // false=关闭, true=打开
unsigned long doorOpenTime = 0;
const unsigned long DOOR_OPEN_DURATION = 3000; // 3秒

void setup() {
  // 初始化串口
  Serial.begin(9600);
  // 先尝试以AT模式波特率连接
  BTSerial.begin(38400); // AT模式常用波特率
  
  Serial.println("尝试AT模式配置...");
  
  // 发送测试AT指令
  sendATCommand("AT");
  delay(1000);
  
  // 如果AT模式无响应，切换到正常模式
  if (!checkATResponse()) {
    Serial.println("未检测到AT模式，切换到正常模式9600波特率");
    BTSerial.end();
    delay(100);
    BTSerial.begin(9600); // 正常模式波特率
  }
  
  // 等待蓝牙模块启动
  delay(1000);
  
  // 发送初始化指令配置HC-05
  Serial.println("正在初始化HC-05蓝牙模块...");
  
  // 注意：以下AT指令需要HC-05进入AT模式才能生效
  // 要进入AT模式：HC-05上电前按住按键，或者连接KEY引脚到3.3V
  sendATCommand("AT+NAME=第八组");
  delay(500);
  sendATCommand("AT+PSWD=");
  delay(500);
  sendATCommand("AT+ROLE=0");
  delay(500);
  sendATCommand("AT+CMODE=1");
  delay(500);
  
  // 初始化RFID
  SPI.begin();
  mfrc522.PCD_Init();
  
  // 初始化舵机
  doorLock.attach(SERVO_PIN);
  doorLock.write(0); // 初始位置：门锁关闭
  
  Serial.println("=== 智能门禁系统启动完成 ===");
  Serial.println("RFID + 蓝牙控制已就绪");
  Serial.println("蓝牙名称: 第八组");
  Serial.println("配对密码: ");
}

void sendATCommand(String command) {
  Serial.print("发送AT指令: ");
  Serial.println(command);
  
  BTSerial.print(command);
  delay(100);
  
  // 读取响应
  Serial.print("AT响应: ");
  while(BTSerial.available()) {
    Serial.write(BTSerial.read());
  }
  Serial.println();
}

// 新增：处理蓝牙指令的函数
void processBluetoothCommand(String command) {
  command.toUpperCase(); // 转换为大写
  command.trim(); // 去除首尾空格
  
  Serial.print("处理蓝牙指令: ");
  Serial.println(command);
  
  if (command == "OPEN" || command == "UNLOCK") {
    Serial.println("✅ 蓝牙指令：开门");
    BTSerial.println("DOOR: Opened by Bluetooth");
    openDoor();
  }
  else if (command == "CLOSE" || command == "LOCK") {
    Serial.println("✅ 蓝牙指令：关门");
    BTSerial.println("DOOR: Closed by Bluetooth");
    closeDoor();
  }
  else if (command == "STATUS" || command == "STATE") {
    printSystemStatus();
  }
  else if (command == "HELP") {
    sendHelpInfo();
  }
  else if (command.startsWith("AT")) {
    // 如果是AT指令，直接转发
    sendATCommand(command);
  }
  else {
    Serial.println("❌ 未知蓝牙指令");
    BTSerial.println("ERROR: Unknown command");
    BTSerial.println("Available: OPEN, CLOSE, STATUS, HELP");
  }
}

void loop() {
  // 1. 处理RFID刷卡
  handleRFID();
  
  // 2. 处理蓝牙指令
  if (BTSerial.available()) {
    String command = "";
    
    // 读取完整指令
    while (BTSerial.available()) {
      char c = BTSerial.read();
      if (c == '\n' || c == '\r') break;
      command += c;
      delay(10); // 稍作延迟确保数据接收完整
    }
    
    command.trim();
    if (command.length() > 0) {
      processBluetoothCommand(command);
    }
  }
  
  // 3. 处理自动关门
  handleAutoClose();
  
  delay(100); // 短暂延迟减少CPU负载
}

void handleRFID() {
  // 检查是否有新卡片
  if (!mfrc522.PICC_IsNewCardPresent()) return;
  if (!mfrc522.PICC_ReadCardSerial()) return;
  
  // 显示卡片信息
  Serial.print("检测到卡片: ");
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    Serial.print(mfrc522.uid.uidByte[i] < 0x10 ? " 0" : " ");
    Serial.print(mfrc522.uid.uidByte[i], HEX);
  }
  Serial.println();
  
  // 验证卡片UID
  if (isAuthorizedCard()) {
    Serial.println("✅ RFID验证成功，开门！");
    BTSerial.println("DOOR: Opened by RFID");
    openDoor();
  } else {
    Serial.println("❌ 未授权卡片！");
    BTSerial.println("DOOR: Unauthorized RFID card");
  }
  
  mfrc522.PICC_HaltA();
}

bool isAuthorizedCard() {
  for (byte i = 0; i < 4; i++) {
    if (mfrc522.uid.uidByte[i] != authorizedUID[i]) {
      return false;
    }
  }
  return true;
}

void openDoor() {
  doorLock.write(90); // 舵机转到90度（开门）
  doorState = true;
  doorOpenTime = millis(); // 记录开门时间
  
  Serial.println("🚪 门已打开");
  if (BTSerial) {
    BTSerial.println("DOOR: OPEN");
  }
}

void closeDoor() {
  doorLock.write(0); // 舵机转到0度（关门）
  doorState = false;
  doorOpenTime = 0;
  
  Serial.println("🚪 门已关闭");
  if (BTSerial) {
    BTSerial.println("DOOR: CLOSED");
  }
}

void handleAutoClose() {
  // 如果门是开着的，且超过了指定时间，自动关门
  if (doorState && (millis() - doorOpenTime > DOOR_OPEN_DURATION)) {
    Serial.println("⏰ 自动关门时间到");
    closeDoor();
  }
}

void printSystemStatus() {
  String status = doorState ? "OPEN" : "CLOSED";
  
  Serial.println("=== 系统状态 ===");
  Serial.print("门状态: ");
  Serial.println(status);
  Serial.print("运行时间: ");
  Serial.print(millis() / 1000);
  Serial.println(" 秒");
  Serial.println("================");
  
  BTSerial.println("=== SYSTEM STATUS ===");
  BTSerial.print("DOOR: ");
  BTSerial.println(status);
  BTSerial.print("UPTIME: ");
  BTSerial.print(millis() / 1000);
  BTSerial.println("s");
  BTSerial.println("====================");
}

void sendHelpInfo() {
  BTSerial.println("=== DOOR LOCK HELP ===");
  BTSerial.println("OPEN    - 开门");
  BTSerial.println("CLOSE   - 强制关门");
  BTSerial.println("STATUS  - 系统状态");
  BTSerial.println("HELP    - 显示帮助");
  BTSerial.println("AT+...  - AT指令");
  BTSerial.println("====================");
}

bool checkATResponse() {
  unsigned long startTime = millis();
  while (millis() - startTime < 1000) {
    if (BTSerial.available()) {
      String response = BTSerial.readString();
      Serial.print("AT响应: ");
      Serial.println(response);
      return response.indexOf("OK") >= 0;
    }
  }
  return false;
}