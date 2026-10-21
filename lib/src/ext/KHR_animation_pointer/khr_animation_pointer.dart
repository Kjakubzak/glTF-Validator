// Copyright 2024 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

library gltf.extensions.khr_animation_pointer;

import 'package:gltf/src/base/gltf_property.dart';
import 'package:gltf/src/ext/extensions.dart';
import 'package:gltf/src/gl.dart' as gl;

const String KHR_ANIMATION_POINTER = 'KHR_animation_pointer';
const String POINTER = 'pointer';

const List<String> KHR_ANIMATION_POINTER_MEMBERS = <String>[POINTER];

enum AnimationPointerValueType {
  boolean,
  float,
  floatArray,
  float2,
  float3,
  float4,
  float2x2,
  float3x3,
  float4x4,
  integer
}

class AnimationPointerResolution {
  final bool exists;
  final int arrayLength;
  final GltfProperty target;

  const AnimationPointerResolution(
      {this.exists, this.arrayLength = 1, this.target});
}

typedef AnimationPointerResolver = AnimationPointerResolution Function(
    Gltf gltf, List<int> indices);
typedef AnimationPointerElementCheckerFactory = ElementChecker Function(
    String path, Accessor accessor, bool hasTangents);

class AnimationPointerProperty {
  final String template;
  final AnimationPointerValueType type;
  final AnimationPointerResolver resolve;
  final double minimum;
  final double maximum;
  final bool exclusiveMinimum;
  final bool exclusiveMaximum;
  final AnimationPointerElementCheckerFactory elementCheckerFactory;

  RegExp _pattern;

  AnimationPointerProperty(this.template, this.type, this.resolve,
      {this.minimum = double.negativeInfinity,
      this.maximum = double.infinity,
      this.exclusiveMinimum = false,
      this.exclusiveMaximum = false,
      this.elementCheckerFactory});

  RegExp get pattern {
    final body = template.split('/').map((s) {
      if (s == '{}') {
        return '(0|[1-9][0-9]*)';
      }
      return RegExp.escape(s);
    }).join('/');
    return _pattern ??= RegExp('^$body\$');
  }

  List<int> match(String pointer) {
    final match = pattern.firstMatch(pointer);
    if (match == null) {
      return null;
    }
    return List<int>.generate(
        match.groupCount, (i) => int.parse(match.group(i + 1)),
        growable: false);
  }

  String get accessorType {
    switch (type) {
      case AnimationPointerValueType.float2:
        return VEC2;
      case AnimationPointerValueType.float3:
        return VEC3;
      case AnimationPointerValueType.float4:
        return VEC4;
      case AnimationPointerValueType.float2x2:
        return MAT2;
      case AnimationPointerValueType.float3x3:
        return MAT3;
      case AnimationPointerValueType.float4x4:
        return MAT4;
      default:
        return SCALAR;
    }
  }

  bool get requiresStep =>
      type == AnimationPointerValueType.boolean ||
      type == AnimationPointerValueType.integer;

  bool acceptsComponentType(Accessor accessor) {
    if (type == AnimationPointerValueType.boolean) {
      return accessor.componentType == gl.UNSIGNED_BYTE && !accessor.normalized;
    }
    if (type == AnimationPointerValueType.integer) {
      return !accessor.normalized && accessor.componentType != gl.FLOAT;
    }
    return true;
  }
}

class KhrAnimationPointer extends GltfProperty {
  final String pointer;
  AnimationPointerProperty _property;
  AnimationPointerProperty get property => _property;

  KhrAnimationPointer._(
      this.pointer, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static final RegExp _pointerRegExp = RegExp(r'^(?:\/(?:[^\/~]|~0|~1)*)*$');

  static KhrAnimationPointer fromMap(Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, KHR_ANIMATION_POINTER_MEMBERS, context);
    }

    return KhrAnimationPointer._(
        getString(map, POINTER, context, req: true, regexp: _pointerRegExp),
        getExtensions(map, KhrAnimationPointer, context),
        getExtras(map, context));
  }

  List<String> get decodedTokens => pointer
      ?.split('/')
      ?.skip(1)
      ?.map((token) => token.replaceAll('~1', '/').replaceAll('~0', '~'))
      ?.toList(growable: false);

  /// An unknown declared extension may define this target's AOM semantics.
  bool hasUnsupportedTargetExtensions(Context context) {
    final tokens = decodedTokens;
    if (tokens == null) return false;
    for (var i = 0; i + 1 < tokens.length; ++i) {
      if (tokens[i] == EXTENSIONS &&
          context.extensionsUsed.contains(tokens[i + 1]) &&
          !context.extensionsLoaded.contains(tokens[i + 1])) return true;
    }
    // A separate declared extension can define mutable semantics for extras.
    return tokens.contains(EXTRAS) &&
        property == null &&
        context.extensionsUsed
            .any((name) => !context.extensionsLoaded.contains(name));
  }

  @override
  void link(Gltf gltf, Context context) {
    final target = context.owners[this];
    if (target is! AnimationChannelTarget) {
      return;
    }
    final animationTarget = target as AnimationChannelTarget;
    if (animationTarget.node != null) {
      context.addIssue(
          SemanticError.khrAnimationPointerAnimationChannelTargetNode);
    }
    if (animationTarget.path != POINTER) {
      context.addIssue(
          SemanticError.khrAnimationPointerAnimationChannelTargetPath,
          args: [animationTarget.path]);
    }
    if (pointer == null) {
      return;
    }

    final tokens = decodedTokens;
    final canonicalPointer = _encodeTokens(tokens);
    List<int> indices;
    _property = context.animationPointerProperties.firstWhere((candidate) {
      indices = candidate.match(canonicalPointer);
      return indices != null;
    }, orElse: () => null);
    if (_property == null) {
      if (tokens.contains(EXTRAS) &&
          _jsonPointerExists(context.rootJson, tokens)) {
        _checkExtrasDuplicateTargets(
            gltf, animationTarget, canonicalPointer, context);
        if (hasUnsupportedTargetExtensions(context)) {
          context.addIssue(LinkError.incompleteExtensionSupport);
        }
        return;
      }
      if (hasUnsupportedTargetExtensions(context)) {
        context.addIssue(LinkError.incompleteExtensionSupport);
        _checkExtrasDuplicateTargets(
            gltf, animationTarget, canonicalPointer, context);
        return;
      }
      context.addIssue(LinkError.khrAnimationPointerUnresolved,
          name: POINTER, args: [pointer]);
      return;
    }
    final resolution = _property.resolve(gltf, indices);
    if (!resolution.exists) {
      context.addIssue(LinkError.khrAnimationPointerUnresolved,
          name: POINTER, args: [pointer]);
      return;
    }
    resolution.target?.markAsUsed();
    _markTargetUsed(gltf, tokens);

    Animation containingAnimation;
    AnimationChannel containingChannel;
    for (final animation in gltf.animations) {
      if (animation == null) {
        continue;
      }
      for (final channel in animation.channels) {
        if (channel?.target == animationTarget) {
          containingAnimation = animation;
          containingChannel = channel;
          break;
        }
      }
      if (containingChannel != null) {
        break;
      }
    }
    final sampler = containingChannel?.sampler;
    final output = sampler?.output;
    if (output != null) {
      if (output.type != _property.accessorType ||
          !_property.acceptsComponentType(output)) {
        context.addIssue(LinkError.khrAnimationPointerInvalidAccessor, args: [
          AccessorFormat.fromAccessor(output),
          _property.accessorType
        ]);
      }
      if (_property.requiresStep && sampler.interpolation != STEP) {
        context.addIssue(LinkError.khrAnimationPointerInvalidInterpolation,
            args: [sampler.interpolation]);
      }
      final inputCount = sampler.input?.count;
      if (inputCount != null && inputCount != -1) {
        var expected = inputCount * resolution.arrayLength;
        if (sampler.interpolation == CUBICSPLINE) {
          expected *= 3;
        }
        if (output.count != -1 && output.count != expected) {
          context.addIssue(LinkError.animationSamplerOutputAccessorInvalidCount,
              args: [expected, output.count]);
        }
      }
      if (_property.minimum.isFinite || _property.maximum.isFinite) {
        context.addElementChecker(
            output,
            _AnimationPointerBoundsChecker(context.getPointerString(),
                _property.minimum, _property.maximum,
                exclusiveMinimum: _property.exclusiveMinimum,
                exclusiveMaximum: _property.exclusiveMaximum));
      }
      if (_property.elementCheckerFactory != null) {
        context.addElementChecker(
            output,
            _property.elementCheckerFactory(context.getPointerString(), output,
                sampler.interpolation == CUBICSPLINE));
      }
    }

    if (containingAnimation != null) {
      final channelIndex =
          containingAnimation.channels.indexOf(containingChannel);
      for (var i = 0; i < containingAnimation.channels.length; ++i) {
        if (i == channelIndex) {
          continue;
        }
        final otherTarget = containingAnimation.channels[i]?.target;
        if (otherTarget == null) {
          continue;
        }
        String otherPointer;
        if (otherTarget.path == POINTER) {
          final other = otherTarget.extensions[KHR_ANIMATION_POINTER];
          if (other is KhrAnimationPointer && other.pointer != null) {
            otherPointer = _encodeTokens(other.decodedTokens);
          }
        } else if (otherTarget.nodeIndex != -1) {
          otherPointer = '/nodes/${otherTarget.nodeIndex}/${otherTarget.path}';
        }
        if (otherPointer != null &&
            _targetsOverlap(canonicalPointer, otherPointer)) {
          context.addIssue(LinkError.animationDuplicateTargets, args: [i]);
        }
      }
    }
  }

  static bool _targetsOverlap(String a, String b) {
    if (a == b) {
      return true;
    }
    bool isElementOf(String element, String array) {
      if (!element.startsWith('$array/')) {
        return false;
      }
      final suffix = element.substring(array.length + 1);
      return !suffix.contains('/') && int.tryParse(suffix) != null;
    }

    return isElementOf(a, b) || isElementOf(b, a);
  }

  static String _encodeTokens(List<String> tokens) =>
      '/${tokens.map((token) => token.replaceAll('~', '~0').replaceAll('/', '~1')).join('/')}';

  static void _checkExtrasDuplicateTargets(Gltf gltf,
      AnimationChannelTarget target, String pointer, Context context) {
    for (final animation in gltf.animations) {
      if (animation == null) {
        continue;
      }
      final channelIndex =
          animation.channels.indexWhere((channel) => channel?.target == target);
      if (channelIndex == -1) {
        continue;
      }
      for (var i = 0; i < animation.channels.length; ++i) {
        if (i == channelIndex) {
          continue;
        }
        final other =
            animation.channels[i]?.target?.extensions[KHR_ANIMATION_POINTER];
        if (other is KhrAnimationPointer && other.pointer != null) {
          final otherPointer = _encodeTokens(other.decodedTokens);
          if (_targetsOverlap(pointer, otherPointer)) {
            context.addIssue(LinkError.animationDuplicateTargets, args: [i]);
          }
        }
      }
      return;
    }
  }

  static bool _jsonPointerExists(Object root, List<String> tokens) {
    var value = root;
    for (final token in tokens) {
      if (value is Map<String, Object>) {
        final object = value as Map<String, Object>;
        if (!object.containsKey(token)) {
          return false;
        }
        value = object[token];
      } else if (value is List<Object>) {
        final array = value as List<Object>;
        if (!RegExp(r'^(?:0|[1-9][0-9]*)$').hasMatch(token)) {
          return false;
        }
        final index = int.parse(token);
        if (index >= array.length) {
          return false;
        }
        value = array[index];
      } else {
        return false;
      }
    }
    return true;
  }

  static void _markTargetUsed(Gltf gltf, List<String> tokens) {
    if (tokens.length < 2) {
      return;
    }
    final index = int.tryParse(tokens[1]);
    if (index == null) {
      return;
    }
    switch (tokens.first) {
      case CAMERAS:
        gltf.cameras[index]?.markAsUsed();
        break;
      case MATERIALS:
        gltf.materials[index]?.markAsUsed();
        break;
      case MESHES:
        gltf.meshes[index]?.markAsUsed();
        break;
      case NODES:
        gltf.nodes[index]?.markAsUsed();
        break;
    }
  }
}

class _AnimationPointerBoundsChecker extends ElementChecker<num> {
  @override
  final String path;
  final double minimum;
  final double maximum;
  final bool exclusiveMinimum;
  final bool exclusiveMaximum;

  _AnimationPointerBoundsChecker(this.path, this.minimum, this.maximum,
      {this.exclusiveMinimum = false, this.exclusiveMaximum = false});

  @override
  bool check(Context context, int index, int componentIndex, num value) {
    if (value < minimum ||
        (exclusiveMinimum && value == minimum) ||
        value > maximum ||
        (exclusiveMaximum && value == maximum)) {
      context.addIssue(DataError.khrAnimationPointerValueOutOfRange,
          name: path, args: [index, componentIndex, value]);
    }
    return true;
  }
}

const Extension khrAnimationPointerExtension = Extension(
    KHR_ANIMATION_POINTER,
    <Type, ExtensionDescriptor>{
      AnimationChannelTarget: ExtensionDescriptor(KhrAnimationPointer.fromMap)
    },
    init: _init);

void _init(Context context) {
  context.animationChannelTargetPaths.add(POINTER);
  context.animationPointerProperties
    ..addAll(_coreProperties)
    ..addAll(_extensionProperties)
    ..addAll(_textureTransformProperties);
}

AnimationPointerResolution _objectAt<T>(SafeList<T> objects, int index) =>
    AnimationPointerResolution(
        exists: objects[index] != null,
        target: objects[index] is GltfProperty
            ? objects[index] as GltfProperty
            : null);

AnimationPointerResolution _materialExtension(
    Gltf gltf, List<int> indices, String name) {
  final extension = gltf.materials[indices[0]]?.extensions[name];
  return AnimationPointerResolution(
      exists: extension is GltfProperty,
      target: extension is GltfProperty ? extension : null);
}

AnimationPointerProperty _materialExtensionProperty(
        String extension, String member, AnimationPointerValueType type,
        {double minimum = double.negativeInfinity,
        double maximum = double.infinity,
        bool exclusiveMinimum = false,
        bool exclusiveMaximum = false}) =>
    AnimationPointerProperty('/materials/{}/extensions/$extension/$member',
        type, (gltf, indices) => _materialExtension(gltf, indices, extension),
        minimum: minimum,
        maximum: maximum,
        exclusiveMinimum: exclusiveMinimum,
        exclusiveMaximum: exclusiveMaximum);

final List<AnimationPointerProperty> _coreProperties =
    <AnimationPointerProperty>[
  AnimationPointerProperty(
      '/cameras/{}/orthographic/xmag', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.orthographic?.xmag;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/cameras/{}/orthographic/ymag', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.orthographic?.ymag;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/cameras/{}/orthographic/zfar', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.orthographic?.zfar;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/cameras/{}/orthographic/znear', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.orthographic?.znear;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/cameras/{}/perspective/aspectRatio', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.perspective?.aspectRatio;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/cameras/{}/perspective/yfov', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.perspective?.yfov;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  },
      minimum: 0,
      maximum: 3.141592653589793,
      exclusiveMinimum: true,
      exclusiveMaximum: true),
  AnimationPointerProperty(
      '/cameras/{}/perspective/zfar', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.perspective?.zfar;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/cameras/{}/perspective/znear', AnimationPointerValueType.float,
      (gltf, i) {
    final value = gltf.cameras[i[0]]?.perspective?.znear;
    return AnimationPointerResolution(exists: value != null && !value.isNaN);
  }, minimum: 0, exclusiveMinimum: true),
  AnimationPointerProperty(
      '/materials/{}/alphaCutoff',
      AnimationPointerValueType.float,
      (gltf, i) => _objectAt(gltf.materials, i[0]),
      minimum: 0),
  AnimationPointerProperty(
      '/materials/{}/emissiveFactor',
      AnimationPointerValueType.float3,
      (gltf, i) => _objectAt(gltf.materials, i[0]),
      minimum: 0),
  AnimationPointerProperty(
      '/materials/{}/normalTexture/scale',
      AnimationPointerValueType.float,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.materials[i[0]]?.normalTexture != null)),
  AnimationPointerProperty(
      '/materials/{}/occlusionTexture/strength',
      AnimationPointerValueType.float,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.materials[i[0]]?.occlusionTexture != null),
      minimum: 0,
      maximum: 1),
  AnimationPointerProperty(
      '/materials/{}/pbrMetallicRoughness/baseColorFactor',
      AnimationPointerValueType.float4,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.materials[i[0]]?.pbrMetallicRoughness != null),
      minimum: 0,
      maximum: 1),
  AnimationPointerProperty(
      '/materials/{}/pbrMetallicRoughness/metallicFactor',
      AnimationPointerValueType.float,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.materials[i[0]]?.pbrMetallicRoughness != null),
      minimum: 0,
      maximum: 1),
  AnimationPointerProperty(
      '/materials/{}/pbrMetallicRoughness/roughnessFactor',
      AnimationPointerValueType.float,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.materials[i[0]]?.pbrMetallicRoughness != null),
      minimum: 0,
      maximum: 1),
  AnimationPointerProperty(
      '/meshes/{}/weights', AnimationPointerValueType.floatArray, (gltf, i) {
    final mesh = gltf.meshes[i[0]];
    return AnimationPointerResolution(
        exists: mesh != null && mesh.morphTargetsCount > 0,
        arrayLength: mesh?.morphTargetsCount ?? 1);
  }),
  AnimationPointerProperty(
      '/meshes/{}/weights/{}', AnimationPointerValueType.float, (gltf, i) {
    final mesh = gltf.meshes[i[0]];
    return AnimationPointerResolution(
        exists: mesh != null && i[1] < mesh.morphTargetsCount);
  }),
  AnimationPointerProperty(
      '/nodes/{}/translation',
      AnimationPointerValueType.float3,
      (gltf, i) =>
          AnimationPointerResolution(exists: gltf.nodes[i[0]] != null)),
  AnimationPointerProperty(
      '/nodes/{}/rotation',
      AnimationPointerValueType.float4,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.nodes[i[0]] != null && gltf.nodes[i[0]].matrix == null),
      minimum: -1,
      maximum: 1,
      elementCheckerFactory: (path, accessor, hasTangents) =>
          QuaternionFloatChecker(
              path, accessor.isFloat ? null : accessor.normalizeValue,
              hasTangents: hasTangents)),
  AnimationPointerProperty(
      '/nodes/{}/scale',
      AnimationPointerValueType.float3,
      (gltf, i) => AnimationPointerResolution(
          exists: gltf.nodes[i[0]] != null && gltf.nodes[i[0]].matrix == null)),
  AnimationPointerProperty(
      '/nodes/{}/weights', AnimationPointerValueType.floatArray, (gltf, i) {
    final node = gltf.nodes[i[0]];
    final count = node?.mesh?.morphTargetsCount ?? 0;
    return AnimationPointerResolution(
        exists: node != null && count > 0, arrayLength: count == 0 ? 1 : count);
  }),
  AnimationPointerProperty(
      '/nodes/{}/weights/{}', AnimationPointerValueType.float, (gltf, i) {
    final node = gltf.nodes[i[0]];
    return AnimationPointerResolution(
        exists: node != null && i[1] < (node.mesh?.morphTargetsCount ?? 0));
  }),
];

AnimationPointerResolution _punctualLight(Gltf gltf, List<int> indices,
    bool Function(KhrLightsPunctualLight) exists) {
  final root = gltf.extensions['KHR_lights_punctual'];
  final light = root is KhrLightsPunctualGltf ? root.lights[indices[0]] : null;
  return AnimationPointerResolution(
      exists: light != null && exists(light), target: light);
}

final List<AnimationPointerProperty> _extensionProperties =
    <AnimationPointerProperty>[
  AnimationPointerProperty('/nodes/{}/extensions/KHR_node_visibility/visible',
      AnimationPointerValueType.boolean, (gltf, i) {
    final extension = gltf.nodes[i[0]]?.extensions[KHR_NODE_VISIBILITY];
    return AnimationPointerResolution(
        exists: extension is KhrNodeVisibility,
        target: extension is GltfProperty ? extension : null);
  }, minimum: 0, maximum: 1),
  AnimationPointerProperty(
      '/extensions/KHR_lights_punctual/lights/{}/color',
      AnimationPointerValueType.float3,
      (gltf, i) => _punctualLight(gltf, i, (_) => true),
      minimum: 0,
      maximum: 1),
  AnimationPointerProperty(
      '/extensions/KHR_lights_punctual/lights/{}/intensity',
      AnimationPointerValueType.float,
      (gltf, i) => _punctualLight(gltf, i, (_) => true),
      minimum: 0),
  AnimationPointerProperty(
      '/extensions/KHR_lights_punctual/lights/{}/range',
      AnimationPointerValueType.float,
      (gltf, i) => _punctualLight(gltf, i, (light) => !light.range.isNaN),
      minimum: 0,
      exclusiveMinimum: true),
  AnimationPointerProperty(
      '/extensions/KHR_lights_punctual/lights/{}/spot/innerConeAngle',
      AnimationPointerValueType.float,
      (gltf, i) => _punctualLight(gltf, i, (light) => light.spot != null),
      minimum: 0,
      maximum: 1.5707963267948966),
  AnimationPointerProperty(
      '/extensions/KHR_lights_punctual/lights/{}/spot/outerConeAngle',
      AnimationPointerValueType.float,
      (gltf, i) => _punctualLight(gltf, i, (light) => light.spot != null),
      minimum: 0,
      maximum: 1.5707963267948966,
      exclusiveMinimum: true),
  _materialExtensionProperty('KHR_materials_anisotropy', 'anisotropyStrength',
      AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_anisotropy', 'anisotropyRotation',
      AnimationPointerValueType.float),
  _materialExtensionProperty('KHR_materials_clearcoat', 'clearcoatFactor',
      AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_clearcoat',
      'clearcoatRoughnessFactor', AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  AnimationPointerProperty(
      '/materials/{}/extensions/KHR_materials_clearcoat/clearcoatNormalTexture/scale',
      AnimationPointerValueType.float, (gltf, i) {
    final extension =
        gltf.materials[i[0]]?.extensions['KHR_materials_clearcoat'];
    return AnimationPointerResolution(
        exists: extension is KhrMaterialsClearcoat &&
            extension.clearcoatNormalTexture != null,
        target: extension is GltfProperty ? extension : null);
  }),
  _materialExtensionProperty(
      'KHR_materials_dispersion', 'dispersion', AnimationPointerValueType.float,
      minimum: 0),
  _materialExtensionProperty('KHR_materials_emissive_strength',
      'emissiveStrength', AnimationPointerValueType.float,
      minimum: 0),
  _materialExtensionProperty(
      'KHR_materials_ior', 'ior', AnimationPointerValueType.float,
      minimum: 1),
  _materialExtensionProperty('KHR_materials_iridescence', 'iridescenceFactor',
      AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_iridescence', 'iridescenceIor',
      AnimationPointerValueType.float,
      minimum: 1),
  _materialExtensionProperty('KHR_materials_iridescence',
      'iridescenceThicknessMinimum', AnimationPointerValueType.float,
      minimum: 0),
  _materialExtensionProperty('KHR_materials_iridescence',
      'iridescenceThicknessMaximum', AnimationPointerValueType.float,
      minimum: 0),
  _materialExtensionProperty('KHR_materials_sheen', 'sheenColorFactor',
      AnimationPointerValueType.float3,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_sheen', 'sheenRoughnessFactor',
      AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_specular', 'specularFactor',
      AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_specular', 'specularColorFactor',
      AnimationPointerValueType.float3,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_transmission', 'transmissionFactor',
      AnimationPointerValueType.float,
      minimum: 0, maximum: 1),
  _materialExtensionProperty('KHR_materials_volume', 'thicknessFactor',
      AnimationPointerValueType.float,
      minimum: 0),
  _materialExtensionProperty('KHR_materials_volume', 'attenuationDistance',
      AnimationPointerValueType.float,
      minimum: 0, exclusiveMinimum: true),
  _materialExtensionProperty('KHR_materials_volume', 'attenuationColor',
      AnimationPointerValueType.float3,
      minimum: 0, maximum: 1),
];

AnimationPointerResolution resolveTextureTransform(
    Gltf gltf, List<int> indices, TextureInfo Function(Material) select) {
  final material = gltf.materials[indices[0]];
  final info = material == null ? null : select(material);
  final transform = info?.extensions[KHR_TEXTURE_TRANSFORM];
  return AnimationPointerResolution(
      exists: transform is KhrTextureTransform,
      target: transform is GltfProperty ? transform : null);
}

List<AnimationPointerProperty> _textureTransformPropertiesFor(
        String texturePath, TextureInfo Function(Material) select) =>
    <AnimationPointerProperty>[
      for (final property in const <String>['offset', 'scale', 'rotation'])
        AnimationPointerProperty(
            '/materials/{}/$texturePath/extensions/KHR_texture_transform/$property',
            property == 'rotation'
                ? AnimationPointerValueType.float
                : AnimationPointerValueType.float2,
            (gltf, i) => resolveTextureTransform(gltf, i, select))
    ];

final List<AnimationPointerProperty> _textureTransformProperties =
    <AnimationPointerProperty>[
  ..._textureTransformPropertiesFor('normalTexture', (m) => m.normalTexture),
  ..._textureTransformPropertiesFor(
      'occlusionTexture', (m) => m.occlusionTexture),
  ..._textureTransformPropertiesFor(
      'emissiveTexture', (m) => m.emissiveTexture),
  ..._textureTransformPropertiesFor('pbrMetallicRoughness/baseColorTexture',
      (m) => m.pbrMetallicRoughness?.baseColorTexture),
  ..._textureTransformPropertiesFor(
      'pbrMetallicRoughness/metallicRoughnessTexture',
      (m) => m.pbrMetallicRoughness?.metallicRoughnessTexture),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_anisotropy/anisotropyTexture', (m) {
    final extension = m.extensions['KHR_materials_anisotropy'];
    return extension is KhrMaterialsAnisotropy
        ? extension.anisotropyTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_clearcoat/clearcoatTexture', (m) {
    final extension = m.extensions['KHR_materials_clearcoat'];
    return extension is KhrMaterialsClearcoat
        ? extension.clearcoatTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_clearcoat/clearcoatRoughnessTexture', (m) {
    final extension = m.extensions['KHR_materials_clearcoat'];
    return extension is KhrMaterialsClearcoat
        ? extension.clearcoatRoughnessTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_clearcoat/clearcoatNormalTexture', (m) {
    final extension = m.extensions['KHR_materials_clearcoat'];
    return extension is KhrMaterialsClearcoat
        ? extension.clearcoatNormalTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_iridescence/iridescenceTexture', (m) {
    final extension = m.extensions['KHR_materials_iridescence'];
    return extension is KhrMaterialsIridescence
        ? extension.iridescenceTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_iridescence/iridescenceThicknessTexture', (m) {
    final extension = m.extensions['KHR_materials_iridescence'];
    return extension is KhrMaterialsIridescence
        ? extension.iridescenceThicknessTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_sheen/sheenColorTexture', (m) {
    final extension = m.extensions['KHR_materials_sheen'];
    return extension is KhrMaterialsSheen ? extension.sheenColorTexture : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_sheen/sheenRoughnessTexture', (m) {
    final extension = m.extensions['KHR_materials_sheen'];
    return extension is KhrMaterialsSheen
        ? extension.sheenRoughnessTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_specular/specularTexture', (m) {
    final extension = m.extensions['KHR_materials_specular'];
    return extension is KhrMaterialsSpecular ? extension.specularTexture : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_specular/specularColorTexture', (m) {
    final extension = m.extensions['KHR_materials_specular'];
    return extension is KhrMaterialsSpecular
        ? extension.specularColorTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_transmission/transmissionTexture', (m) {
    final extension = m.extensions['KHR_materials_transmission'];
    return extension is KhrMaterialsTransmission
        ? extension.transmissionTexture
        : null;
  }),
  ..._textureTransformPropertiesFor(
      'extensions/KHR_materials_volume/thicknessTexture', (m) {
    final extension = m.extensions['KHR_materials_volume'];
    return extension is KhrMaterialsVolume ? extension.thicknessTexture : null;
  }),
];
