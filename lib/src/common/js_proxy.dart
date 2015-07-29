// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library polymer.lib.src.common.js_proxy;

import 'dart:js';
import 'package:polymer_interop/polymer_interop.dart';
export 'package:polymer_interop/polymer_interop.dart' show dartValue, jsValue;
import 'package:reflectable/reflectable.dart';
import 'declarations.dart';

/// Mixin this class to get js proxy support! If a [JsProxy] is passed to
/// [jsValue] then you will get back a [JsObject] which is fully usable from
/// JS, but proxies all method calls and properties to the dart instance.
/// Calling [dartValue] on that [JsObject] will also return the original dart
/// instance (not a copy).
abstract class JsProxy implements JsProxyInterface {
  /// Lazily create proxy constructors!
  static Map<Type, JsFunction> _jsProxyConstructors = {};

  /// Never reads from the dart object, instead reads properties from the
  /// `__cache__` object. This is primarily useful for objects that you pass in
  /// empty, and the javascript code will populate. It should be used carefully
  /// since its easy to get the two objects out of sync.
  bool useCache = false;

  /// The Javascript constructor that will be used to build proxy objects for
  /// this class.
  JsFunction get jsProxyConstructor {
    var type = runtimeType;
    return _jsProxyConstructors.putIfAbsent(
        type, () => _buildJsConstructorForType(type));
  }

  JsObject _jsProxy;
  JsObject get jsProxy {
    if (_jsProxy == null) _jsProxy = _buildJsProxy(this);
    return _jsProxy;
  }
}

/// Wraps an instance of a dart class in a js proxy.
JsObject _buildJsProxy(JsProxy instance) {
  var constructor = instance.jsProxyConstructor;
  var proxy = new JsObject(constructor);
  addDartInstance(proxy, instance);
  if (instance.useCache) {
    proxy['__cache__'] = new JsObject(context['Object']);
  }

  return proxy;
}

/// The [Reflectable] class which gives you the ability to do everything that
/// PolymerElements and JsProxies need to do.
class JsProxyReflectable extends Reflectable {
  const JsProxyReflectable()
      : super(
            instanceInvokeCapability,
            metadataCapability,
            declarationsCapability,
            typeCapability,
            typeRelationsCapability,
            subtypeQuantifyCapability,
            superclassQuantifyCapability,
            const StaticInvokeCapability('hostAttributes'));
}

const jsProxyReflectable = const JsProxyReflectable();

final JsObject _polymerDart = context['Polymer']['Dart'];

/// Given a dart type, this creates a javascript constructor and prototype
/// which can act as a proxy for it.
JsFunction _buildJsConstructorForType(Type dartType) {
  var constructor = _polymerDart.callMethod('functionFactory');
  var prototype = new JsObject(context['Object']);

  var declarations = declarationsFor(dartType, jsProxyReflectable);
  declarations.forEach((String name, DeclarationMirror declaration) {
    if (isProperty(declaration)) {
      var descriptor = {
        'get': _polymerDart.callMethod('propertyAccessorFactory', [
          name,
          (dartInstance) {
            var mirror = jsProxyReflectable.reflect(dartInstance);
            return jsValue(mirror.invokeGetter(name));
          }
        ]),
        'configurable': false,
      };
      if (!isFinal(declaration)) {
        descriptor['set'] = _polymerDart.callMethod('propertySetterFactory', [
          name,
          (dartInstance, value) {
            var mirror = jsProxyReflectable.reflect(dartInstance);
            mirror.invokeSetter(name, dartValue(value));
          }
        ]);
      }
      // Add a proxy getter/setter for this property.
      context['Object'].callMethod(
          'defineProperty', [prototype, name, new JsObject.jsify(descriptor),]);
    } else if (isRegularMethod(declaration)) {
      // TODO(jakemac): consolidate this code with the code in properties.dart.
      prototype[name] = _polymerDart.callMethod('invokeDartFactory', [
        (dartInstance, arguments) {
          var newArgs = arguments.map((arg) => dartValue(arg)).toList();
          var mirror = jsProxyReflectable.reflect(dartInstance);
          return mirror.invoke(name, newArgs);
        }
      ]);
    }
  });

  constructor['prototype'] = prototype;
  return constructor;
}