// Copyright 2024 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gltf/gltf.dart';
import 'package:gltf/src/errors.dart';
import 'package:test/test.dart';

import '../../utils.dart';

Future main() async {
  await compareReports('test/ext/KHR_animation_pointer');

  group('Evaluate valid objects', () {
    test('animation.channel.target.KHR_animation_pointer', () async {
      final gltf = (await read(
              'ext/KHR_animation_pointer/data/animation/channel/target/valid.gltf',
              ignoreUnused: true,
              ignoreIncomplete: true))
          .gltf;

      final target0 = gltf.animations[0].channels[0].target;
      expect(target0.node, isNull);
      expect(target0.path, 'pointer');
      final pointer0 =
          target0.extensions['KHR_animation_pointer'] as KhrAnimationPointer;
      expect(pointer0.pointer,
          '/materials/0/pbrMetallicRoughness/baseColorFactor');
      expect(pointer0.extensions, isEmpty);

      final target1 = gltf.animations[0].channels[1].target;
      expect(target1.node, isNull);
      expect(target1.path, 'pointer');
      final pointer1 =
          target1.extensions['KHR_animation_pointer'] as KhrAnimationPointer;
      expect(pointer1.pointer,
          '/materials/0/pbrMetallicRoughness/roughnessFactor');
      expect(pointer1.extensions, isEmpty);
    });
  });

  group('Object model validation', () {
    Future<GltfJsonReader> readMap(Map<String, Object> map,
        [Context context]) async {
      final reader = GltfJsonReader(
          Stream<List<int>>.value(utf8.encode(jsonEncode(map))), context);
      await reader.read();
      return reader;
    }

    Future<Map<String, Object>> validMap() async => (jsonDecode(
            await File('test/ext/KHR_animation_pointer/data/animation/channel/'
                    'target/valid.gltf')
                .readAsString()) as Map)
        .cast<String, Object>();

    void retainFirstChannel(Map<String, Object> map) {
      final animation =
          (map['animations'] as List<Object>)[0] as Map<String, Object>;
      (animation['channels'] as List<Object>).removeRange(1, 2);
      (animation['samplers'] as List<Object>).removeRange(1, 2);
    }

    void setPointer(Map<String, Object> map, String pointer) {
      final animation =
          (map['animations'] as List<Object>)[0] as Map<String, Object>;
      final channel =
          (animation['channels'] as List<Object>)[0] as Map<String, Object>;
      final target = channel['target'] as Map<String, Object>;
      final extensions = target['extensions'] as Map<String, Object>;
      (extensions[KHR_ANIMATION_POINTER] as Map<String, Object>)['pointer'] =
          pointer;
    }

    Context customContextWith(List<AnimationPointerProperty> properties) {
      final context = Context()
        ..registerExtensions(<Extension>[
          Extension(KHR_ANIMATION_POINTER, <Type, ExtensionDescriptor>{
            AnimationChannelTarget:
                const ExtensionDescriptor(KhrAnimationPointer.fromMap)
          }, init: (context) {
            context.animationChannelTargetPaths.add(POINTER);
            context.animationPointerProperties.addAll(properties);
          })
        ]);
      return context;
    }

    Context customContext(AnimationPointerProperty property) =>
        customContextWith(<AnimationPointerProperty>[property]);

    test('properties supplied by defaults resolve', () async {
      final reader = await readMap(await validMap());
      expect(
          reader.context.issues.where((issue) =>
              issue.type == LinkError.khrAnimationPointerUnresolved ||
              issue.type == LinkError.incompleteExtensionSupport),
          isEmpty);
    });

    test('default registry covers core and supported extension properties',
        () async {
      final reader = await readMap(await validMap());
      final templates = reader.context.animationPointerProperties
          .map((property) => property.template)
          .toSet();
      expect(templates, hasLength(99));
      expect(
          templates,
          containsAll(<String>[
            '/nodes/{}/translation',
            '/meshes/{}/weights/{}',
            '/extensions/KHR_lights_punctual/lights/{}/spot/outerConeAngle',
            '/materials/{}/extensions/KHR_materials_anisotropy/anisotropyStrength',
            '/materials/{}/extensions/KHR_materials_clearcoat/clearcoatNormalTexture/scale',
            '/materials/{}/extensions/KHR_materials_dispersion/dispersion',
            '/materials/{}/extensions/KHR_materials_emissive_strength/emissiveStrength',
            '/materials/{}/extensions/KHR_materials_ior/ior',
            '/materials/{}/extensions/KHR_materials_iridescence/iridescenceThicknessMaximum',
            '/materials/{}/extensions/KHR_materials_sheen/sheenColorFactor',
            '/materials/{}/extensions/KHR_materials_specular/specularColorFactor',
            '/materials/{}/extensions/KHR_materials_transmission/transmissionFactor',
            '/materials/{}/extensions/KHR_materials_volume/attenuationColor',
            '/materials/{}/extensions/KHR_materials_volume/thicknessTexture/extensions/KHR_texture_transform/offset'
          ]));
    });

    test('supported extension-defined properties resolve', () async {
      final map = await validMap();
      retainFirstChannel(map);
      (map['extensionsUsed'] as List<Object>)
        ..add('KHR_materials_anisotropy')
        ..add('KHR_texture_transform');
      (map['materials'] as List<Object>)[0] = <String, Object>{
        'extensions': <String, Object>{
          'KHR_materials_anisotropy': <String, Object>{
            'anisotropyTexture': <String, Object>{
              'index': 0,
              'extensions': <String, Object>{
                'KHR_texture_transform': <String, Object>{}
              }
            }
          }
        }
      };
      map['textures'] = <Object>[<String, Object>{}];
      for (final pointer in <String>[
        '/materials/0/extensions/KHR_materials_anisotropy/anisotropyStrength',
        '/materials/0/extensions/KHR_materials_anisotropy/anisotropyTexture/extensions/KHR_texture_transform/rotation'
      ]) {
        setPointer(map, pointer);
        final output =
            (map['accessors'] as List<Object>)[1] as Map<String, Object>;
        output['type'] = 'SCALAR';
        final reader = await readMap(map);
        expect(
            reader.context.issues.where((issue) =>
                issue.type == LinkError.khrAnimationPointerUnresolved),
            isEmpty,
            reason: pointer);
      }
    });

    test('escaped extras tokens remain application-defined', () async {
      final map = await validMap();
      final materials = map['materials'] as List<Object>;
      (materials[0] as Map<String, Object>)['extras'] = <String, Object>{
        'custom/value': 0
      };
      final animations = map['animations'] as List<Object>;
      final animation = animations[0] as Map<String, Object>;
      final channels = animation['channels'] as List<Object>;
      final target =
          (channels[0] as Map<String, Object>)['target'] as Map<String, Object>;
      final extensions = target['extensions'] as Map<String, Object>;
      (extensions[KHR_ANIMATION_POINTER] as Map<String, Object>)['pointer'] =
          '/materials/0/extras/custom~1value';
      final reader = await readMap(map);
      expect(
          reader.context.issues.where(
              (issue) => issue.type == LinkError.khrAnimationPointerUnresolved),
          isEmpty);
    });

    test('extras pointers must resolve structurally', () async {
      final map = await validMap();
      retainFirstChannel(map);
      setPointer(map, '/materials/0/extras/missing');
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.khrAnimationPointerUnresolved));
    });

    test('duplicate extras targets are rejected', () async {
      final map = await validMap();
      (map['materials'] as List<Object>)[0] = <String, Object>{
        'extras': <String, Object>{'value': 1}
      };
      setPointer(map, '/materials/0/extras/value');
      final animation =
          (map['animations'] as List<Object>)[0] as Map<String, Object>;
      final channels = animation['channels'] as List<Object>;
      final target =
          (channels[1] as Map<String, Object>)['target'] as Map<String, Object>;
      final extensions = target['extensions'] as Map<String, Object>;
      (extensions[KHR_ANIMATION_POINTER] as Map<String, Object>)['pointer'] =
          '/materials/0/extras/value';
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.animationDuplicateTargets));
    });

    test('array indices use canonical RFC 6901 syntax', () async {
      final map = await validMap();
      retainFirstChannel(map);
      setPointer(map, '/materials/00/pbrMetallicRoughness/baseColorFactor');
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.khrAnimationPointerUnresolved));
    });

    test('escaped slashes remain within one pointer token', () async {
      final map = await validMap();
      retainFirstChannel(map);
      setPointer(map, '/custom/value~1path');
      final property = AnimationPointerProperty(
          '/custom/value/path',
          AnimationPointerValueType.float,
          (_, __) => const AnimationPointerResolution(exists: true));
      final reader = await readMap(map, customContext(property));
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.khrAnimationPointerUnresolved));
    });

    test('defaults require their enclosing object', () async {
      final map = await validMap();
      retainFirstChannel(map);
      (map['materials'] as List<Object>)[0] = <String, Object>{};
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.khrAnimationPointerUnresolved));
    });

    test('incompatible output accessor is rejected', () async {
      final map = await validMap();
      final accessors = map['accessors'] as List<Object>;
      (accessors[1] as Map<String, Object>)['type'] = 'VEC3';
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.khrAnimationPointerInvalidAccessor));
    });

    test('duplicate pointer targets are rejected', () async {
      final map = await validMap();
      final animations = map['animations'] as List<Object>;
      final animation = animations[0] as Map<String, Object>;
      final channels = animation['channels'] as List<Object>;
      final target =
          (channels[1] as Map<String, Object>)['target'] as Map<String, Object>;
      final extensions = target['extensions'] as Map<String, Object>;
      (extensions[KHR_ANIMATION_POINTER] as Map<String, Object>)['pointer'] =
          '/materials/0/pbrMetallicRoughness/baseColorFactor';
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.animationDuplicateTargets));
    });

    test('pointer and ordinary node targets cannot overlap', () async {
      final map = await validMap();
      map['nodes'] = <Object>[<String, Object>{}];
      final animation =
          (map['animations'] as List<Object>)[0] as Map<String, Object>;
      final channels = animation['channels'] as List<Object>;
      final pointerTarget =
          (channels[0] as Map<String, Object>)['target'] as Map<String, Object>;
      final pointerExtensions =
          pointerTarget['extensions'] as Map<String, Object>;
      (pointerExtensions[KHR_ANIMATION_POINTER]
          as Map<String, Object>)['pointer'] = '/nodes/0/translation';
      (map['accessors'] as List<Object>)[1] = <String, Object>{
        'componentType': 5126,
        'count': 2,
        'type': 'VEC3'
      };
      (channels[1] as Map<String, Object>)['target'] = <String, Object>{
        'node': 0,
        'path': 'translation'
      };
      final reader = await readMap(map);
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.animationDuplicateTargets));
    });

    test('array and array-element targets cannot overlap', () async {
      final map = await validMap();
      setPointer(map, '/custom/values');
      final animation =
          (map['animations'] as List<Object>)[0] as Map<String, Object>;
      final channels = animation['channels'] as List<Object>;
      final secondTarget =
          (channels[1] as Map<String, Object>)['target'] as Map<String, Object>;
      final extensions = secondTarget['extensions'] as Map<String, Object>;
      (extensions[KHR_ANIMATION_POINTER] as Map<String, Object>)['pointer'] =
          '/custom/values/0';
      (map['accessors'] as List<Object>)[1] = <String, Object>{
        'componentType': 5126,
        'count': 4,
        'type': 'SCALAR'
      };
      final properties = <AnimationPointerProperty>[
        AnimationPointerProperty(
            '/custom/values',
            AnimationPointerValueType.floatArray,
            (_, __) =>
                const AnimationPointerResolution(exists: true, arrayLength: 2)),
        AnimationPointerProperty(
            '/custom/values/{}',
            AnimationPointerValueType.float,
            (_, __) => const AnimationPointerResolution(exists: true))
      ];
      final reader = await readMap(map, customContextWith(properties));
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.animationDuplicateTargets));
    });

    test('float array output count includes array length', () async {
      final map = await validMap();
      retainFirstChannel(map);
      setPointer(map, '/custom/values');
      ((map['accessors'] as List<Object>)[1] as Map<String, Object>)
        ..['type'] = 'SCALAR'
        ..['count'] = 2;
      final property = AnimationPointerProperty(
          '/custom/values',
          AnimationPointerValueType.floatArray,
          (_, __) =>
              const AnimationPointerResolution(exists: true, arrayLength: 2));
      final reader = await readMap(map, customContext(property));
      expect(reader.context.issues.map((issue) => issue.type),
          contains(LinkError.animationSamplerOutputAccessorInvalidCount));
    });

    test('extensions can register every object model value type', () async {
      final cases = <AnimationPointerValueType, String>{
        AnimationPointerValueType.boolean: 'SCALAR',
        AnimationPointerValueType.float: 'SCALAR',
        AnimationPointerValueType.floatArray: 'SCALAR',
        AnimationPointerValueType.float2: 'VEC2',
        AnimationPointerValueType.float3: 'VEC3',
        AnimationPointerValueType.float4: 'VEC4',
        AnimationPointerValueType.float2x2: 'MAT2',
        AnimationPointerValueType.float3x3: 'MAT3',
        AnimationPointerValueType.float4x4: 'MAT4',
        AnimationPointerValueType.integer: 'SCALAR'
      };
      for (final entry in cases.entries) {
        final map = await validMap();
        retainFirstChannel(map);
        setPointer(map, '/custom/value');
        final output =
            (map['accessors'] as List<Object>)[1] as Map<String, Object>;
        output['type'] = entry.value;
        output['componentType'] =
            entry.key == AnimationPointerValueType.boolean ? 5121 : 5126;
        final animation =
            (map['animations'] as List<Object>)[0] as Map<String, Object>;
        final sampler =
            (animation['samplers'] as List<Object>)[0] as Map<String, Object>;
        if (entry.key == AnimationPointerValueType.boolean ||
            entry.key == AnimationPointerValueType.integer) {
          output['componentType'] =
              entry.key == AnimationPointerValueType.boolean ? 5121 : 5125;
          sampler['interpolation'] = 'STEP';
        }
        final property = AnimationPointerProperty('/custom/value', entry.key,
            (_, __) => const AnimationPointerResolution(exists: true));
        final reader = await readMap(map, customContext(property));
        expect(
            reader.context.issues.where((issue) =>
                issue.type == LinkError.khrAnimationPointerInvalidAccessor ||
                issue.type ==
                    LinkError.khrAnimationPointerInvalidInterpolation),
            isEmpty,
            reason: '${entry.key} should accept ${entry.value}');
      }
    });

    test('integer and Boolean properties require STEP interpolation', () async {
      for (final type in <AnimationPointerValueType>[
        AnimationPointerValueType.boolean,
        AnimationPointerValueType.integer
      ]) {
        final map = await validMap();
        retainFirstChannel(map);
        setPointer(map, '/custom/value');
        ((map['accessors'] as List<Object>)[1] as Map<String, Object>)
          ..['type'] = 'SCALAR'
          ..['componentType'] =
              type == AnimationPointerValueType.boolean ? 5121 : 5125;
        final property = AnimationPointerProperty('/custom/value', type,
            (_, __) => const AnimationPointerResolution(exists: true));
        final reader = await readMap(map, customContext(property));
        expect(reader.context.issues.map((issue) => issue.type),
            contains(LinkError.khrAnimationPointerInvalidInterpolation));
      }
    });

    test('registered value bounds attach an output checker', () async {
      final map = await validMap();
      retainFirstChannel(map);
      setPointer(map, '/custom/value');
      final property = AnimationPointerProperty(
          '/custom/value',
          AnimationPointerValueType.float,
          (_, __) => const AnimationPointerResolution(exists: true),
          minimum: 0,
          maximum: 1);
      final reader = await readMap(map, customContext(property));
      final checker = reader.context.accessorElementCheckers.values
          .expand((checkers) => checkers)
          .where((checker) => checker.path.contains('KHR_animation_pointer'))
          .single;
      final context = reader.context;
      checker.check(context, 0, 0, 1.5);
      expect(context.issues.map((issue) => issue.type),
          contains(DataError.khrAnimationPointerValueOutOfRange));
    });
  });
}
