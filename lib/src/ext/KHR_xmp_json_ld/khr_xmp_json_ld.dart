// Copyright 2026 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

library gltf.extensions.khr_xmp_json_ld;

import 'package:gltf/src/base/gltf_property.dart';
import 'package:gltf/src/ext/extensions.dart';

const String KHR_XMP_JSON_LD = 'KHR_xmp_json_ld';
const String PACKET = 'packet';
const String PACKETS = 'packets';
const String CONTEXT = '@context';

const List<String> KHR_XMP_JSON_LD_GLTF_MEMBERS = <String>[PACKETS];
const List<String> KHR_XMP_JSON_LD_REFERENCE_MEMBERS = <String>[PACKET];

class KhrXmpJsonLdPacket extends GltfProperty {
  final Map<String, Object> metadata;
  final Map<String, String> context;

  KhrXmpJsonLdPacket._(this.metadata, this.context)
      : super(const <String, Object>{}, null);

  static KhrXmpJsonLdPacket fromMap(Map<String, Object> map, Context context) {
    final contextMap = getMap(map, CONTEXT, context, req: true);
    final namespaces = <String, String>{};
    final namespaceUris = <String>{};

    if (contextMap != null) {
      context.path.add(CONTEXT);
      contextMap.forEach((prefix, value) {
        if (prefix == '@base' || prefix == '@vocab') {
          return;
        }
        if (value is String) {
          final uri = Uri.tryParse(value);
          if (uri == null || !uri.hasScheme) {
            context.addIssue(SemanticError.khrXmpJsonLdInvalidContextValue,
                name: prefix, args: [value]);
          } else if (!namespaceUris.add(value)) {
            context.addIssue(SemanticError.khrXmpJsonLdDuplicateNamespace,
                name: prefix, args: [value]);
          }
          namespaces[prefix] = value;
        } else {
          context.addIssue(SchemaError.typeMismatch,
              name: prefix, args: [value, 'string']);
        }
      });
      context.path.removeLast();
    }

    if (context.validate) {
      _validateObject(map, context, namespaces, isPacket: true);
    }
    return KhrXmpJsonLdPacket._(Map<String, Object>.unmodifiable(map),
        Map<String, String>.unmodifiable(namespaces));
  }

  static final RegExp _compactIri = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*:[^\s:]+$');
  static final RegExp _rdfMember = RegExp(r'^rdf:_([1-9][0-9]*)$');
  static final RegExp _languageTag = RegExp(r'^[a-z]{2,8}(?:-[a-z0-9]{1,8})*$');

  static void _validateObject(
      Map<String, Object> map, Context context, Map<String, String> namespaces,
      {bool isPacket = false, bool inLanguageAlternative = false}) {
    final hasLanguageValueKeyword =
        map.containsKey('@language') || map.containsKey('@value');
    if (hasLanguageValueKeyword) {
      final validMembers =
          map.keys.every((key) => key == '@language' || key == '@value');
      final language = map['@language'];
      final value = map['@value'];
      if (!validMembers || language is! String || value is! String) {
        context.addIssue(SemanticError.khrXmpJsonLdInvalidValueObject);
      } else if (!_languageTag.hasMatch(language as String)) {
        context.addIssue(SemanticError.khrXmpJsonLdInvalidLanguageTag,
            name: '@language', args: [language]);
      }
      return;
    }

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == CONTEXT) {
        if (!isPacket) {
          final language = value is Map<String, Object> && value.length == 1
              ? value['@language']
              : null;
          if (language is! String) {
            context.addIssue(SemanticError.khrXmpJsonLdLocalContext, name: key);
          } else if (!_languageTag.hasMatch(language as String)) {
            context.addIssue(SemanticError.khrXmpJsonLdInvalidLanguageTag,
                name: key, args: [language]);
          }
        }
        continue;
      }

      final isKeyword = key.startsWith('@');
      if (!isKeyword && !_compactIri.hasMatch(key)) {
        context.addIssue(SemanticError.khrXmpJsonLdInvalidCompactIri,
            name: key, args: [key]);
      } else if (!isKeyword) {
        final prefix = key.substring(0, key.indexOf(':'));
        if (!namespaces.containsKey(prefix)) {
          context.addIssue(SemanticError.khrXmpJsonLdUndefinedPrefix,
              name: key, args: [prefix]);
        }
      }

      context.path.add(key);
      if (key == '@type' && value is String && value != 'rdf:Alt') {
        if (!_compactIri.hasMatch(value)) {
          context.addIssue(SemanticError.khrXmpJsonLdInvalidCompactIri,
              args: [value]);
        } else {
          final prefix = value.substring(0, value.indexOf(':'));
          if (!namespaces.containsKey(prefix)) {
            context.addIssue(SemanticError.khrXmpJsonLdUndefinedPrefix,
                args: [prefix]);
          }
        }
      }
      if (value is List<Object>) {
        context.addIssue(SemanticError.khrXmpJsonLdUnwrappedArray);
        _validateArray(value, context, namespaces,
            inLanguageAlternative: inLanguageAlternative);
      } else if (value is Map<String, Object>) {
        final isArrayWrapper = value.length == 1 &&
            (value.containsKey('@list') || value.containsKey('@set'));
        final isAlt = value['@type'] == 'rdf:Alt';

        if (isArrayWrapper) {
          final wrapper = value.keys.single;
          final array = value[wrapper];
          if (array is List<Object>) {
            context.path.add(wrapper);
            _validateArray(array, context, namespaces,
                inLanguageAlternative: inLanguageAlternative);
            context.path.removeLast();
          } else {
            context.addIssue(SchemaError.typeMismatch,
                name: wrapper, args: [array, 'array']);
          }
        } else {
          _validateObject(value, context, namespaces,
              inLanguageAlternative: isAlt);
          if (isAlt) {
            if (namespaces['rdf'] !=
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#') {
              context.addIssue(
                  SemanticError.khrXmpJsonLdInvalidLanguageAlternative,
                  name: '@type');
            }
            for (final altKey in value.keys.where((k) => k != '@type')) {
              if (!_rdfMember.hasMatch(altKey)) {
                context.addIssue(
                    SemanticError.khrXmpJsonLdInvalidLanguageAlternative,
                    name: altKey);
              }
            }
          }
        }
      }
      context.path.removeLast();
    }
  }

  static void _validateArray(
      List<Object> array, Context context, Map<String, String> namespaces,
      {bool inLanguageAlternative = false}) {
    for (var i = 0; i < array.length; ++i) {
      final value = array[i];
      if (value is Map<String, Object>) {
        context.path.add(i.toString());
        _validateObject(value, context, namespaces,
            inLanguageAlternative: inLanguageAlternative);
        context.path.removeLast();
      } else if (value is List<Object>) {
        context.addIssue(SemanticError.khrXmpJsonLdUnwrappedArray, index: i);
      }
    }
  }
}

class KhrXmpJsonLdGltf extends GltfProperty {
  final SafeList<KhrXmpJsonLdPacket> packets;

  KhrXmpJsonLdGltf._(
      this.packets, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrXmpJsonLdGltf fromMap(Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, KHR_XMP_JSON_LD_GLTF_MEMBERS, context);
    }
    final packetMaps = getMapList(map, PACKETS, context);
    final packets = packetMaps == null
        ? SafeList<KhrXmpJsonLdPacket>.empty(PACKETS)
        : SafeList<KhrXmpJsonLdPacket>(packetMaps.length, PACKETS);
    if (packetMaps != null) {
      context.path.add(PACKETS);
      for (var i = 0; i < packetMaps.length; ++i) {
        context.path.add(i.toString());
        packets[i] = KhrXmpJsonLdPacket.fromMap(packetMaps[i], context);
        context.path.removeLast();
      }
      context.path.removeLast();
    }
    return KhrXmpJsonLdGltf._(packets,
        getExtensions(map, KhrXmpJsonLdGltf, context), getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    context.path.add(PACKETS);
    packets.forEachWithIndices((i, packet) {
      if (!packet.isUsed) {
        context.addIssue(LinkError.unusedObject, index: i);
      }
    });
    context.path.removeLast();
  }
}

class KhrXmpJsonLdReference extends GltfProperty {
  final int packetIndex;
  KhrXmpJsonLdPacket _packet;
  KhrXmpJsonLdPacket get packet => _packet;

  KhrXmpJsonLdReference._(
      this.packetIndex, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrXmpJsonLdReference fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, KHR_XMP_JSON_LD_REFERENCE_MEMBERS, context);
    }
    return KhrXmpJsonLdReference._(
        getIndex(map, PACKET, context),
        getExtensions(map, KhrXmpJsonLdReference, context),
        getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    final root = gltf.extensions[KHR_XMP_JSON_LD];
    if (root is KhrXmpJsonLdGltf) {
      _packet = root.packets[packetIndex];
    } else {
      context
          .addIssue(SchemaError.unsatisfiedDependency, args: [KHR_XMP_JSON_LD]);
      return;
    }
    if (packetIndex != -1) {
      if (_packet == null) {
        context.addIssue(LinkError.unresolvedReference,
            name: PACKET, args: [packetIndex]);
      } else {
        _packet.markAsUsed();
      }
    }
  }
}

const Extension khrXmpJsonLdExtension =
    Extension(KHR_XMP_JSON_LD, <Type, ExtensionDescriptor>{
  Gltf: ExtensionDescriptor(KhrXmpJsonLdGltf.fromMap),
  Asset: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
  Scene: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
  Node: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
  Mesh: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
  Material: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
  Image: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
  Animation: ExtensionDescriptor(KhrXmpJsonLdReference.fromMap),
});
