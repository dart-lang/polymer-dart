// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library polymer.test.src.micro.dom_distribution_test;

import 'dart:html';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';
import 'package:polymer/polymer_mini.dart';
import 'package:smoke/mirrors.dart' as smoke;

PolymerElement element;

main() async {
  useHtmlConfiguration();
  smoke.useMirrors();
  await initPolymer();

  test('Simple', () {
    element = document.querySelector('simple-element');
    var div = element.querySelector('.content #hello');
    expect(div, isNotNull);
    expect(div.text, 'hello!');
  });

  test('Selector', () {
    element = document.querySelector('select-element');
    var div = element.querySelector('.content #invisible');
    expect(div, isNull);

    div = element.querySelector('.content #hello');
    expect(div, isNotNull);
    expect(div.text, 'hello!');

    expect(element.querySelector('#invisible'), isNull);
    expect(document.querySelector('#invisible'), isNull);
  });
}

@PolymerRegister('simple-element')
class SimpleElement extends PolymerElement {
  SimpleElement.created() : super.created();
}

@PolymerRegister('select-element')
class SelectElement extends PolymerElement {
  SelectElement.created() : super.created();
}
