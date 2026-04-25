// 占位 smoke test：原 flutter create 模板里的 Counter 计数器测试引用了
// 项目里不存在的 MyApp，已废弃。保留文件结构便于后续补充真实 widget 测试。

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder smoke test', () {
    expect(1 + 1, 2);
  });
}
