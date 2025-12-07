@Entry
@Component
export struct LogPage {
  build() {
    Column() {
      Text('日志记录界面')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
      Text('这里显示蓝牙连接、门禁操作等历史记录')
        .fontSize(16)
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}