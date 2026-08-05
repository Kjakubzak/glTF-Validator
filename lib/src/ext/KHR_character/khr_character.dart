// Copyright 2026 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

library gltf.extensions.khr_character;

import 'package:gltf/src/base/gltf_property.dart';
import 'package:gltf/src/ext/extensions.dart';

const String KHR_CHARACTER = 'KHR_character';
const String KHR_CHARACTER_EXPRESSION = 'KHR_character_expression';
const String KHR_CHARACTER_EXPRESSION_JOINT = 'KHR_character_expression_joint';
const String KHR_CHARACTER_EXPRESSION_MORPHTARGET =
    'KHR_character_expression_morphtarget';
const String KHR_CHARACTER_EXPRESSION_TEXTURE =
    'KHR_character_expression_texture';
const String KHR_CHARACTER_EXPRESSION_MASK = 'KHR_character_expression_mask';
const String KHR_CHARACTER_EXPRESSION_MAPPING =
    'KHR_character_expression_mapping';
const String KHR_CHARACTER_SKELETON_MAPPING = 'KHR_character_skeleton_mapping';
const String KHR_CHARACTER_REFERENCE_POSE = 'KHR_character_reference_pose';
const String KHR_NODE_CAMERA_HINT = 'KHR_node_camera_hint';
const String KHR_NODE_LOOKAT_TARGET = 'KHR_node_lookat_target';
const String KHR_NODE_VISIBILITY_HINT = 'KHR_node_visibility_hint';
const String KHR_MESH_PRIMITIVE_VISIBILITY_HINT =
    'KHR_mesh_primitive_visibility_hint';

const String ROOT_NODE = 'rootNode';
const String EXPRESSIONS = 'expressions';
const String EXPRESSION = 'expression';
const String ANIMATION = 'animation';
const String EXPRESSION_SET_MAPPINGS = 'expressionSetMappings';
const String EXPRESSION_SET_INPUT_MAPPINGS = 'expressionSetInputMappings';
const String MAPPING_SOURCE = 'source';
const String MAPPING_TARGET = 'target';
const String WEIGHT = 'weight';
const String MASKS = 'masks';
const String AMOUNT = 'amount';
const String THRESHOLD = 'threshold';
const String SKELETAL_RIG_MAPPINGS = 'skeletalRigMappings';
const String POSE_TYPE = 'poseType';
const String ROLE = 'role';
const String CAMERA = 'camera';
const String TARGET_NODE = 'targetNode';
const String LABEL = 'label';
const String HINT = 'hint';

final RegExp _nonEmpty = RegExp('.+');

bool _isAbsoluteUri(String value) {
  try {
    return Uri.parse(value).isAbsolute;
  } on FormatException {
    return false;
  }
}

void _withPath(Context context, Iterable<String> path, void Function() action) {
  final previousPath = context.path.toList(growable: false);
  context.path
    ..clear()
    ..addAll(path);
  try {
    action();
  } finally {
    context.path
      ..clear()
      ..addAll(previousPath);
  }
}

void _requireUsed(Gltf gltf, Context context, String extension) {
  if (!gltf.extensionsUsed.contains(extension)) {
    context.addIssue(SchemaError.unsatisfiedDependency, args: [extension]);
  }
}

void _requireRootObject(Gltf gltf, Context context, String extension) {
  _requireUsed(gltf, context, extension);
  if (!gltf.extensions.containsKey(extension)) {
    context.addIssue(SchemaError.unsatisfiedDependency, args: [extension]);
  }
}

class KhrCharacter extends GltfProperty {
  final int rootNodeIndex;
  Node _rootNode;
  Node get rootNode => _rootNode;

  KhrCharacter._(
      this.rootNodeIndex, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacter fromMap(Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[ROOT_NODE], context);
    }
    return KhrCharacter._(getIndex(map, ROOT_NODE, context),
        getExtensions(map, KhrCharacter, context), getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    _rootNode = gltf.nodes[rootNodeIndex];
    if (rootNodeIndex != -1) {
      if (_rootNode == null) {
        context.addIssue(LinkError.unresolvedReference,
            name: ROOT_NODE, args: [rootNodeIndex]);
      } else {
        _rootNode.markAsUsed();
      }
    }
  }
}

abstract class KhrCharacterExpressionChannelSet extends GltfProperty {
  final List<int> channelIndices;
  List<AnimationChannel> _channels;
  List<AnimationChannel> get channels => _channels;

  KhrCharacterExpressionChannelSet(
      this.channelIndices, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  void linkExpression(Gltf gltf, Animation animation, Context context,
      bool Function(AnimationChannel channel) accepts,
      {LinkError invalidTarget}) {
    _channels =
        List<AnimationChannel>.filled(channelIndices?.length ?? 0, null);
    context.path.add(CHANNELS);
    for (var i = 0; i < (channelIndices?.length ?? 0); ++i) {
      final index = channelIndices[i];
      final channel = animation?.channels[index];
      _channels[i] = channel;
      if (channel == null) {
        context
            .addIssue(LinkError.unresolvedReference, index: i, args: [index]);
      } else if (!accepts(channel)) {
        context.addIssue(
            invalidTarget ?? LinkError.khrCharacterInvalidExpressionTarget,
            index: i);
      }
    }
    context.path.removeLast();
  }
}

class KhrCharacterExpressionJoint extends KhrCharacterExpressionChannelSet {
  KhrCharacterExpressionJoint._(
      List<int> channels, Map<String, Object> extensions, Object extras)
      : super(channels, extensions, extras);

  static KhrCharacterExpressionJoint fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[CHANNELS], context);
    }
    return KhrCharacterExpressionJoint._(
        getIndicesList(map, CHANNELS, context, req: true),
        getExtensions(map, KhrCharacterExpressionJoint, context),
        getExtras(map, context));
  }
}

class KhrCharacterExpressionMorphTarget
    extends KhrCharacterExpressionChannelSet {
  KhrCharacterExpressionMorphTarget._(
      List<int> channels, Map<String, Object> extensions, Object extras)
      : super(channels, extensions, extras);

  static KhrCharacterExpressionMorphTarget fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[CHANNELS], context);
    }
    return KhrCharacterExpressionMorphTarget._(
        getIndicesList(map, CHANNELS, context, req: true),
        getExtensions(map, KhrCharacterExpressionMorphTarget, context),
        getExtras(map, context));
  }
}

class KhrCharacterExpressionTexture extends KhrCharacterExpressionChannelSet {
  KhrCharacterExpressionTexture._(
      List<int> channels, Map<String, Object> extensions, Object extras)
      : super(channels, extensions, extras);

  static KhrCharacterExpressionTexture fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[CHANNELS], context);
    }
    return KhrCharacterExpressionTexture._(
        getIndicesList(map, CHANNELS, context, req: true),
        getExtensions(map, KhrCharacterExpressionTexture, context),
        getExtras(map, context));
  }
}

class KhrCharacterExpressionMaskEntry extends GltfProperty {
  final int targetIndex;
  KhrCharacterExpressionEntry _target;
  KhrCharacterExpressionEntry get target => _target;
  final String name;
  final String type;
  final double amount;
  final double threshold;

  KhrCharacterExpressionMaskEntry._(
      this.targetIndex,
      this.name,
      this.type,
      this.amount,
      this.threshold,
      Map<String, Object> extensions,
      Object extras)
      : super(extensions, extras);

  static KhrCharacterExpressionMaskEntry fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(
          map, const <String>[TARGET, NAME, TYPE, AMOUNT, THRESHOLD], context);
    }
    return KhrCharacterExpressionMaskEntry._(
        getIndex(map, TARGET, context),
        getString(map, NAME, context),
        getString(map, TYPE, context, def: 'blend', regexp: _nonEmpty),
        getFloat(map, AMOUNT, context, min: 0, max: 1, def: 1),
        getFloat(map, THRESHOLD, context, min: 0, max: 1, def: 0),
        getExtensions(map, KhrCharacterExpressionMaskEntry, context),
        getExtras(map, context));
  }
}

class KhrCharacterExpressionMask extends GltfProperty {
  final SafeList<KhrCharacterExpressionMaskEntry> masks;

  KhrCharacterExpressionMask._(
      this.masks, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterExpressionMask fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[MASKS], context);
    }
    final maps = getMapList(map, MASKS, context);
    final masks = maps == null
        ? SafeList<KhrCharacterExpressionMaskEntry>.empty(MASKS)
        : SafeList<KhrCharacterExpressionMaskEntry>(maps.length, MASKS);
    if (maps != null) {
      context.path.add(MASKS);
      for (var i = 0; i < maps.length; ++i) {
        context.path.add(i.toString());
        masks[i] = KhrCharacterExpressionMaskEntry.fromMap(maps[i], context);
        context.path.removeLast();
      }
      context.path.removeLast();
    }
    final result = KhrCharacterExpressionMask._(
        masks,
        getExtensions(map, KhrCharacterExpressionMask, context),
        getExtras(map, context));
    context.registerObjectsOwner(result, masks);
    return result;
  }

  void linkExpressions(
      SafeList<KhrCharacterExpressionEntry> expressions, Context context) {
    context.path.add(MASKS);
    masks.forEachWithIndices((i, mask) {
      context.path.add(i.toString());
      mask._target = expressions[mask.targetIndex];
      if (mask.targetIndex != -1 && mask._target == null) {
        context.addIssue(LinkError.unresolvedReference,
            name: TARGET, args: [mask.targetIndex]);
      } else if (mask.name != null && mask.name != mask._target?.expression) {
        context.addIssue(LinkError.khrCharacterReferenceNameMismatch,
            name: NAME, args: [mask.name, mask._target?.expression]);
      }
      context.path.removeLast();
    });
    context.path.removeLast();
  }
}

class KhrCharacterExpressionEntry extends GltfProperty {
  final String expression;
  final int animationIndex;
  Animation _animation;
  Animation get animation => _animation;

  KhrCharacterExpressionEntry._(this.expression, this.animationIndex,
      Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterExpressionEntry fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[EXPRESSION, ANIMATION], context);
    }
    final extensions = getExtensions(map, KhrCharacterExpressionEntry, context);
    final result = KhrCharacterExpressionEntry._(
        getString(map, EXPRESSION, context, req: true),
        getIndex(map, ANIMATION, context),
        extensions,
        getExtras(map, context));
    context.registerObjectsOwner(result, extensions.values);
    return result;
  }

  void linkEntry(Gltf gltf, SafeList<KhrCharacterExpressionEntry> expressions,
      Context context) {
    _animation = gltf.animations[animationIndex];
    if (_animation == null) {
      if (animationIndex != -1) {
        context.addIssue(LinkError.unresolvedReference,
            name: ANIMATION, args: [animationIndex]);
      }
    } else {
      _animation.markAsUsed();
    }
    context.path.add(EXTENSIONS);
    extensions.forEach((name, extension) {
      context.path.add(name);
      if (extension is KhrCharacterExpressionJoint) {
        if (_animation != null) {
          extension.linkExpression(gltf, _animation, context, (channel) {
            final path = channel.target?.path;
            return channel.target?.node != null &&
                (path == TRANSLATION || path == ROTATION || path == SCALE);
          });
        }
      } else if (extension is KhrCharacterExpressionMorphTarget) {
        if (_animation != null) {
          extension.linkExpression(gltf, _animation, context, (channel) {
            if (channel.target?.path == WEIGHTS &&
                channel.target?.node != null) {
              return true;
            }
            final pointer = channel.target?.extensions[KHR_ANIMATION_POINTER];
            return pointer is KhrAnimationPointer &&
                pointer.property?.template?.startsWith('/nodes/{}/weights') ==
                    true;
          });
        }
      } else if (extension is KhrCharacterExpressionTexture) {
        _requireUsed(gltf, context, KHR_ANIMATION_POINTER);
        _requireUsed(gltf, context, KHR_TEXTURE_TRANSFORM);
        if (_animation != null) {
          extension.linkExpression(gltf, _animation, context, (channel) {
            final pointer = channel.target?.extensions[KHR_ANIMATION_POINTER];
            return pointer is KhrAnimationPointer &&
                pointer.property?.template
                        ?.contains('/extensions/KHR_texture_transform/') ==
                    true;
          },
              invalidTarget:
                  LinkError.khrCharacterInvalidTextureExpressionPointer);
        }
      } else if (extension is KhrCharacterExpressionMask) {
        extension.linkExpressions(expressions, context);
      }
      context.path.removeLast();
    });
    context.path.removeLast();
  }
}

class KhrCharacterExpression extends GltfProperty {
  final SafeList<KhrCharacterExpressionEntry> expressions;

  KhrCharacterExpression._(
      this.expressions, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterExpression fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[EXPRESSIONS], context);
    }
    final maps = getMapList(map, EXPRESSIONS, context);
    final expressions = maps == null
        ? SafeList<KhrCharacterExpressionEntry>.empty(EXPRESSIONS)
        : SafeList<KhrCharacterExpressionEntry>(maps.length, EXPRESSIONS);
    if (maps != null) {
      context.path.add(EXPRESSIONS);
      for (var i = 0; i < maps.length; ++i) {
        context.path.add(i.toString());
        expressions[i] = KhrCharacterExpressionEntry.fromMap(maps[i], context);
        context.path.removeLast();
      }
      context.path.removeLast();
    }
    final result = KhrCharacterExpression._(
        expressions,
        getExtensions(map, KhrCharacterExpression, context),
        getExtras(map, context));
    context.registerObjectsOwner(result, expressions);
    return result;
  }

  @override
  void link(Gltf gltf, Context context) {
    _requireRootObject(gltf, context, KHR_CHARACTER);
    context.path.add(EXPRESSIONS);
    expressions.forEachWithIndices((i, expression) {
      context.path.add(i.toString());
      expression.linkEntry(gltf, expressions, context);
      context.path.removeLast();
    });
    context.path.removeLast();
  }
}

class KhrCharacterExpressionMappingSource extends GltfProperty {
  final int sourceIndex;
  KhrCharacterExpressionEntry _source;
  KhrCharacterExpressionEntry get source => _source;
  final String name;
  final double weight;

  KhrCharacterExpressionMappingSource._(this.sourceIndex, this.name,
      this.weight, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterExpressionMappingSource fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[MAPPING_SOURCE, NAME, WEIGHT], context);
    }
    return KhrCharacterExpressionMappingSource._(
        getIndex(map, MAPPING_SOURCE, context),
        getString(map, NAME, context, regexp: _nonEmpty),
        getFloat(map, WEIGHT, context, req: true, min: 0, max: 1),
        getExtensions(map, KhrCharacterExpressionMappingSource, context),
        getExtras(map, context));
  }
}

class KhrCharacterExpressionMappingTarget extends GltfProperty {
  final int targetIndex;
  KhrCharacterExpressionEntry _target;
  KhrCharacterExpressionEntry get target => _target;
  final String name;
  final double weight;

  KhrCharacterExpressionMappingTarget._(this.targetIndex, this.name,
      this.weight, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterExpressionMappingTarget fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[MAPPING_TARGET, NAME, WEIGHT], context);
    }
    return KhrCharacterExpressionMappingTarget._(
        getIndex(map, MAPPING_TARGET, context),
        getString(map, NAME, context, regexp: _nonEmpty),
        getFloat(map, WEIGHT, context, req: true, min: 0, max: 1),
        getExtensions(map, KhrCharacterExpressionMappingTarget, context),
        getExtras(map, context));
  }
}

Map<String, Map<String, List<T>>> _parseExpressionMappingOperation<T>(
    Map<String, Object> map,
    String operationName,
    Context context,
    T Function(Map<String, Object>, Context) fromMap) {
  final result = <String, Map<String, List<T>>>{};
  if (!map.containsKey(operationName)) {
    return result;
  }
  final setMaps = getMap(map, operationName, context);
  if (setMaps == null) {
    return result;
  }

  context.path.add(operationName);
  if (setMaps.isEmpty) {
    context.addIssue(SchemaError.emptyEntity);
  }
  setMaps.forEach((setName, value) {
    if (!_isAbsoluteUri(setName)) {
      context.addIssue(LinkError.khrCharacterMappingSetIdentifierNotAbsolute,
          name: setName, args: [setName]);
    }
    if (value is Map<String, Object>) {
      final mappings = <String, List<T>>{};
      result[setName] = mappings;
      context.path.add(setName);
      if (value.isEmpty) {
        context.addIssue(SchemaError.emptyEntity);
      }
      value.forEach((endpointName, entriesValue) {
        if (endpointName.isEmpty) {
          context.addIssue(SchemaError.emptyEntity, name: endpointName);
        }
        if (entriesValue is List<Object>) {
          if (entriesValue.isEmpty) {
            context.addIssue(SchemaError.emptyEntity, name: endpointName);
            return;
          }
          final entries = <T>[];
          mappings[endpointName] = entries;
          context.path.add(endpointName);
          for (var i = 0; i < entriesValue.length; ++i) {
            final entryMap = entriesValue[i];
            if (entryMap is Map<String, Object>) {
              context.path.add(i.toString());
              entries.add(fromMap(entryMap, context));
              context.path.removeLast();
            } else {
              context.addIssue(SchemaError.arrayTypeMismatch,
                  index: i, args: [entryMap, 'object']);
            }
          }
          context.path.removeLast();
        } else {
          context.addIssue(SchemaError.typeMismatch,
              name: endpointName, args: [entriesValue, 'array']);
        }
      });
      context.path.removeLast();
    } else {
      context.addIssue(SchemaError.typeMismatch,
          name: setName, args: [value, 'object']);
    }
  });
  context.path.removeLast();
  return result;
}

class KhrCharacterExpressionMapping extends GltfProperty {
  final Map<String, Map<String, List<KhrCharacterExpressionMappingSource>>>
      expressionSetMappings;
  final Map<String, Map<String, List<KhrCharacterExpressionMappingTarget>>>
      expressionSetInputMappings;

  KhrCharacterExpressionMapping._(
      this.expressionSetMappings,
      this.expressionSetInputMappings,
      Map<String, Object> extensions,
      Object extras)
      : super(extensions, extras);

  static KhrCharacterExpressionMapping fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(
          map,
          const <String>[
            EXPRESSION_SET_MAPPINGS,
            EXPRESSION_SET_INPUT_MAPPINGS
          ],
          context);
      if (!map.containsKey(EXPRESSION_SET_MAPPINGS) &&
          !map.containsKey(EXPRESSION_SET_INPUT_MAPPINGS)) {
        context
            .addIssue(LinkError.khrCharacterExpressionMappingMissingOperation);
      }
    }
    return KhrCharacterExpressionMapping._(
        _parseExpressionMappingOperation<KhrCharacterExpressionMappingSource>(
            map,
            EXPRESSION_SET_MAPPINGS,
            context,
            KhrCharacterExpressionMappingSource.fromMap),
        _parseExpressionMappingOperation<KhrCharacterExpressionMappingTarget>(
            map,
            EXPRESSION_SET_INPUT_MAPPINGS,
            context,
            KhrCharacterExpressionMappingTarget.fromMap),
        getExtensions(map, KhrCharacterExpressionMapping, context),
        getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    _requireRootObject(gltf, context, KHR_CHARACTER);
    _requireRootObject(gltf, context, KHR_CHARACTER_EXPRESSION);
    final expressionRoot = gltf.extensions[KHR_CHARACTER_EXPRESSION];
    if (expressionRoot is! KhrCharacterExpression) {
      return;
    }
    final expressions = (expressionRoot as KhrCharacterExpression).expressions;
    context.path.add(EXPRESSION_SET_MAPPINGS);
    expressionSetMappings.forEach((setName, mappings) {
      context.path.add(setName);
      mappings.forEach((targetName, sources) {
        context.path.add(targetName);
        for (var i = 0; i < sources.length; ++i) {
          final source = sources[i];
          source._source = expressions[source.sourceIndex];
          if (source.sourceIndex != -1 && source._source == null) {
            context.addIssue(LinkError.unresolvedReference,
                index: i, args: [source.sourceIndex]);
          } else if (source.name != null &&
              source.name != source._source?.expression) {
            context.path.add(i.toString());
            context.addIssue(LinkError.khrCharacterReferenceNameMismatch,
                name: NAME, args: [source.name, source._source?.expression]);
            context.path.removeLast();
          }
        }
        context.path.removeLast();
      });
      context.path.removeLast();
    });
    context.path.removeLast();

    context.path.add(EXPRESSION_SET_INPUT_MAPPINGS);
    expressionSetInputMappings.forEach((setName, mappings) {
      context.path.add(setName);
      mappings.forEach((endpointName, targets) {
        context.path.add(endpointName);
        for (var i = 0; i < targets.length; ++i) {
          final target = targets[i];
          target._target = expressions[target.targetIndex];
          if (target.targetIndex != -1 && target._target == null) {
            context.addIssue(LinkError.unresolvedReference,
                index: i, args: [target.targetIndex]);
          } else if (target.name != null &&
              target.name != target._target?.expression) {
            context.path.add(i.toString());
            context.addIssue(LinkError.khrCharacterReferenceNameMismatch,
                name: NAME, args: [target.name, target._target?.expression]);
            context.path.removeLast();
          }
        }
        context.path.removeLast();
      });
      context.path.removeLast();
    });
    context.path.removeLast();
  }
}

class KhrCharacterSkeletonMappingJointAssociation extends GltfProperty {
  final int nodeIndex;
  final String name;
  Node _node;
  Node get node => _node;

  KhrCharacterSkeletonMappingJointAssociation._(
      this.nodeIndex, this.name, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterSkeletonMappingJointAssociation fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[NODE, NAME], context);
    }
    return KhrCharacterSkeletonMappingJointAssociation._(
        getIndex(map, NODE, context),
        getString(map, NAME, context),
        getExtensions(
            map, KhrCharacterSkeletonMappingJointAssociation, context),
        getExtras(map, context));
  }
}

class KhrCharacterSkeletonMapping extends GltfProperty {
  final Map<String, Map<String, KhrCharacterSkeletonMappingJointAssociation>>
      skeletalRigMappings;

  KhrCharacterSkeletonMapping._(
      this.skeletalRigMappings, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterSkeletonMapping fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[SKELETAL_RIG_MAPPINGS], context);
    }
    final result =
        <String, Map<String, KhrCharacterSkeletonMappingJointAssociation>>{};
    final associations = <KhrCharacterSkeletonMappingJointAssociation>[];
    final rigs = getMap(map, SKELETAL_RIG_MAPPINGS, context, req: true);
    if (rigs != null) {
      context.path.add(SKELETAL_RIG_MAPPINGS);
      if (rigs.isEmpty) {
        context.addIssue(SchemaError.emptyEntity);
      }
      rigs.forEach((rig, value) {
        if (!_isAbsoluteUri(rig)) {
          context.addIssue(
              LinkError.khrCharacterMappingSetIdentifierNotAbsolute,
              name: rig,
              args: [rig]);
        }
        if (value is Map<String, Object>) {
          final joints =
              <String, KhrCharacterSkeletonMappingJointAssociation>{};
          result[rig] = joints;
          context.path.add(rig);
          if (value.isEmpty) {
            context.addIssue(SchemaError.emptyEntity);
          }
          value.forEach((joint, associationValue) {
            if (joint.isEmpty) {
              context.addIssue(SchemaError.emptyEntity, name: joint);
            }
            if (associationValue is Map<String, Object>) {
              context.path.add(joint);
              final association =
                  KhrCharacterSkeletonMappingJointAssociation.fromMap(
                      associationValue, context);
              joints[joint] = association;
              associations.add(association);
              context.path.removeLast();
            } else {
              context.addIssue(SchemaError.typeMismatch,
                  name: joint, args: [associationValue, 'object']);
            }
          });
          context.path.removeLast();
        } else {
          context.addIssue(SchemaError.typeMismatch,
              name: rig, args: [value, 'object']);
        }
      });
      context.path.removeLast();
    }
    final mapping = KhrCharacterSkeletonMapping._(
        result,
        getExtensions(map, KhrCharacterSkeletonMapping, context),
        getExtras(map, context));
    context.registerObjectsOwner(mapping, associations);
    return mapping;
  }

  @override
  void link(Gltf gltf, Context context) {
    _requireRootObject(gltf, context, KHR_CHARACTER);
    context.path.add(SKELETAL_RIG_MAPPINGS);
    skeletalRigMappings.forEach((rig, joints) {
      context.path.add(rig);
      joints.forEach((joint, association) {
        association._node = gltf.nodes[association.nodeIndex];
        if (association._node == null) {
          context.addIssue(LinkError.unresolvedReference,
              name: joint, args: [association.nodeIndex]);
        } else {
          association._node.markAsUsed();
          if (association.name != null &&
              association.name != association._node.name) {
            context.path.add(joint);
            context.addIssue(LinkError.khrCharacterReferenceNameMismatch,
                name: NAME, args: [association.name, association._node.name]);
            context.path.removeLast();
          }
        }
      });
      context.path.removeLast();
    });
    context.path.removeLast();
  }
}

class KhrCharacterReferencePose extends GltfProperty {
  final String poseType;

  KhrCharacterReferencePose._(
      this.poseType, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrCharacterReferencePose fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[POSE_TYPE], context);
    }
    return KhrCharacterReferencePose._(
        getString(map, POSE_TYPE, context, def: 'TPose', regexp: _nonEmpty),
        getExtensions(map, KhrCharacterReferencePose, context),
        getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    _requireRootObject(gltf, context, KHR_CHARACTER);
    final animationIndex = gltf.animations.indexWhere((animation) =>
        animation?.extensions[KHR_CHARACTER_REFERENCE_POSE] == this);
    if (animationIndex == -1) {
      return;
    }

    final animation = gltf.animations[animationIndex];
    _withPath(context, <String>[ANIMATIONS, animationIndex.toString()], () {
      if (animation.channels == null || animation.channels.isEmpty) {
        context.addIssue(LinkError.khrCharacterReferencePoseNoChannels,
            name: CHANNELS);
        return;
      }

      final referencedSamplers = <AnimationSampler>{};
      context.path.add(CHANNELS);
      animation.channels.forEachWithIndices((index, channel) {
        context.path.add(index.toString());
        final target = channel?.target;
        if (target == null ||
            target.nodeIndex == -1 ||
            (target.path != TRANSLATION &&
                target.path != ROTATION &&
                target.path != SCALE)) {
          context.addIssue(LinkError.khrCharacterReferencePoseInvalidTarget,
              name: TARGET);
        }
        if (channel?.sampler != null) {
          referencedSamplers.add(channel.sampler);
        }
        context.path.removeLast();
      });
      context.path.removeLast();

      context.path.add(SAMPLERS);
      for (final sampler in referencedSamplers) {
        final samplerIndex = animation.samplers.indexOf(sampler);
        context.path.add(samplerIndex.toString());
        if (sampler.input != null && sampler.input.count != 1) {
          context.addIssue(LinkError.khrCharacterReferencePoseInputCount,
              name: INPUT, args: [sampler.input.count]);
        }
        if (sampler.interpolation != LINEAR && sampler.interpolation != STEP) {
          context.addIssue(
              LinkError.khrCharacterReferencePoseInvalidInterpolation,
              name: INTERPOLATION,
              args: [sampler.interpolation]);
        }
        context.path.removeLast();
      }
      context.path.removeLast();
    });
  }
}

class KhrNodeCameraHint extends GltfProperty {
  final String role;
  final int cameraIndex;
  final int targetNodeIndex;
  final String label;
  Camera _camera;
  Node _targetNode;
  Camera get camera => _camera;
  Node get targetNode => _targetNode;

  KhrNodeCameraHint._(this.role, this.cameraIndex, this.targetNodeIndex,
      this.label, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrNodeCameraHint fromMap(Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(
          map, const <String>[ROLE, CAMERA, TARGET_NODE, LABEL], context);
    }
    return KhrNodeCameraHint._(
        getString(map, ROLE, context, req: true, regexp: _nonEmpty),
        getIndex(map, CAMERA, context, req: false),
        getIndex(map, TARGET_NODE, context, req: false),
        getString(map, LABEL, context, regexp: _nonEmpty),
        getExtensions(map, KhrNodeCameraHint, context),
        getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    _camera = gltf.cameras[cameraIndex];
    if (cameraIndex != -1) {
      if (_camera == null) {
        context.addIssue(LinkError.unresolvedReference,
            name: CAMERA, args: [cameraIndex]);
      } else {
        _camera.markAsUsed();
      }
    }
    _targetNode = gltf.nodes[targetNodeIndex];
    if (targetNodeIndex != -1) {
      if (_targetNode == null) {
        context.addIssue(LinkError.unresolvedReference,
            name: TARGET_NODE, args: [targetNodeIndex]);
      } else {
        _targetNode.markAsUsed();
        final containingIndex = gltf.nodes.indexWhere(
            (node) => node?.extensions[KHR_NODE_CAMERA_HINT] == this);
        if (containingIndex == targetNodeIndex) {
          context.addIssue(LinkError.khrNodeCameraHintSelfReference,
              name: TARGET_NODE);
        }
      }
    }
  }
}

class KhrNodeLookAtTarget extends GltfProperty {
  final String hint;

  KhrNodeLookAtTarget._(
      this.hint, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrNodeLookAtTarget fromMap(Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[HINT], context);
    }
    return KhrNodeLookAtTarget._(
        getString(map, HINT, context, regexp: _nonEmpty),
        getExtensions(map, KhrNodeLookAtTarget, context),
        getExtras(map, context));
  }
}

class KhrNodeVisibilityHint extends GltfProperty {
  final String role;
  final String label;

  KhrNodeVisibilityHint._(
      this.role, this.label, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrNodeVisibilityHint fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[ROLE, LABEL], context);
    }
    return KhrNodeVisibilityHint._(
        getString(map, ROLE, context, req: true, regexp: _nonEmpty),
        getString(map, LABEL, context, regexp: _nonEmpty),
        getExtensions(map, KhrNodeVisibilityHint, context),
        getExtras(map, context));
  }
}

class KhrMeshPrimitiveVisibilityHint extends GltfProperty {
  final String role;
  final String label;

  KhrMeshPrimitiveVisibilityHint._(
      this.role, this.label, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static KhrMeshPrimitiveVisibilityHint fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, const <String>[ROLE, LABEL], context);
    }
    return KhrMeshPrimitiveVisibilityHint._(
        getString(map, ROLE, context, req: true, regexp: _nonEmpty),
        getString(map, LABEL, context, regexp: _nonEmpty),
        getExtensions(map, KhrMeshPrimitiveVisibilityHint, context),
        getExtras(map, context));
  }
}

const Extension khrCharacterExtension =
    Extension(KHR_CHARACTER, <Type, ExtensionDescriptor>{
  Gltf: ExtensionDescriptor(KhrCharacter.fromMap),
});

const Extension khrCharacterExpressionExtension =
    Extension(KHR_CHARACTER_EXPRESSION, <Type, ExtensionDescriptor>{
  Gltf: ExtensionDescriptor(KhrCharacterExpression.fromMap),
});

const Extension khrCharacterExpressionJointExtension =
    Extension(KHR_CHARACTER_EXPRESSION_JOINT, <Type, ExtensionDescriptor>{
  KhrCharacterExpressionEntry:
      ExtensionDescriptor(KhrCharacterExpressionJoint.fromMap, localLink: true),
});

const Extension khrCharacterExpressionMorphTargetExtension =
    Extension(KHR_CHARACTER_EXPRESSION_MORPHTARGET, <Type, ExtensionDescriptor>{
  KhrCharacterExpressionEntry: ExtensionDescriptor(
      KhrCharacterExpressionMorphTarget.fromMap,
      localLink: true),
});

const Extension khrCharacterExpressionTextureExtension =
    Extension(KHR_CHARACTER_EXPRESSION_TEXTURE, <Type, ExtensionDescriptor>{
  KhrCharacterExpressionEntry: ExtensionDescriptor(
      KhrCharacterExpressionTexture.fromMap,
      localLink: true),
});

const Extension khrCharacterExpressionMaskExtension =
    Extension(KHR_CHARACTER_EXPRESSION_MASK, <Type, ExtensionDescriptor>{
  KhrCharacterExpressionEntry:
      ExtensionDescriptor(KhrCharacterExpressionMask.fromMap, localLink: true),
});

const Extension khrCharacterExpressionMappingExtension =
    Extension(KHR_CHARACTER_EXPRESSION_MAPPING, <Type, ExtensionDescriptor>{
  Gltf: ExtensionDescriptor(KhrCharacterExpressionMapping.fromMap),
});

const Extension khrCharacterSkeletonMappingExtension =
    Extension(KHR_CHARACTER_SKELETON_MAPPING, <Type, ExtensionDescriptor>{
  Gltf: ExtensionDescriptor(KhrCharacterSkeletonMapping.fromMap),
});

const Extension khrCharacterReferencePoseExtension =
    Extension(KHR_CHARACTER_REFERENCE_POSE, <Type, ExtensionDescriptor>{
  Animation: ExtensionDescriptor(KhrCharacterReferencePose.fromMap),
});

const Extension khrNodeCameraHintExtension =
    Extension(KHR_NODE_CAMERA_HINT, <Type, ExtensionDescriptor>{
  Node: ExtensionDescriptor(KhrNodeCameraHint.fromMap),
});

const Extension khrNodeLookAtTargetExtension =
    Extension(KHR_NODE_LOOKAT_TARGET, <Type, ExtensionDescriptor>{
  Node: ExtensionDescriptor(KhrNodeLookAtTarget.fromMap),
});

const Extension khrNodeVisibilityHintExtension =
    Extension(KHR_NODE_VISIBILITY_HINT, <Type, ExtensionDescriptor>{
  Node: ExtensionDescriptor(KhrNodeVisibilityHint.fromMap),
});

const Extension khrMeshPrimitiveVisibilityHintExtension =
    Extension(KHR_MESH_PRIMITIVE_VISIBILITY_HINT, <Type, ExtensionDescriptor>{
  MeshPrimitive: ExtensionDescriptor(KhrMeshPrimitiveVisibilityHint.fromMap),
});
