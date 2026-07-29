// Copyright 2026 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:gltf/gltf.dart';
import 'package:gltf/src/errors.dart';
import 'package:test/test.dart';

class _ReadResult {
  final GltfReaderResult result;
  final Context context;

  _ReadResult(this.result, this.context);
}

Future<_ReadResult> _read(Map<String, Object> json) async {
  final reader =
      GltfJsonReader(Stream<List<int>>.value(utf8.encode(jsonEncode(json))));
  return _ReadResult(await reader.read(), reader.context);
}

Map<String, Object> _reference([int packet = 0]) => <String, Object>{
      'extensions': <String, Object>{
        KHR_XMP_JSON_LD: <String, Object>{'packet': packet}
      }
    };

Future<void> main() async {
  test('packet references link from every legal attachment', () async {
    final json = <String, Object>{
      'asset': <String, Object>{
        'version': '2.0',
        ..._reference(),
      },
      'extensionsUsed': <Object>[KHR_XMP_JSON_LD],
      'extensions': <String, Object>{
        KHR_XMP_JSON_LD: <String, Object>{
          'packets': <Object>[
            <String, Object>{
              '@context': <String, Object>{
                'dc': 'http://purl.org/dc/elements/1.1/'
              },
              'dc:title': 'Example'
            }
          ]
        }
      },
      'accessors': <Object>[
        <String, Object>{
          'componentType': 5126,
          'count': 1,
          'type': 'VEC3',
          'min': <Object>[0, 0, 0],
          'max': <Object>[0, 0, 0]
        },
        <String, Object>{
          'componentType': 5126,
          'count': 1,
          'type': 'SCALAR',
          'min': <Object>[0],
          'max': <Object>[0]
        },
        <String, Object>{'componentType': 5126, 'count': 1, 'type': 'VEC3'}
      ],
      'animations': <Object>[
        <String, Object>{
          ..._reference(),
          'channels': <Object>[
            <String, Object>{
              'sampler': 0,
              'target': <String, Object>{'node': 0, 'path': 'translation'}
            }
          ],
          'samplers': <Object>[
            <String, Object>{'input': 1, 'output': 2}
          ]
        }
      ],
      'images': <Object>[
        <String, Object>{
          ..._reference(),
          'uri': 'data:image/png;base64,'
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
              '+A8AAQUBAScY42YAAAAASUVORK5CYII='
        }
      ],
      'materials': <Object>[_reference()],
      'meshes': <Object>[
        <String, Object>{
          ..._reference(),
          'primitives': <Object>[
            <String, Object>{
              'attributes': <String, Object>{'POSITION': 0},
              'material': 0
            }
          ]
        }
      ],
      'nodes': <Object>[_reference()],
      'scenes': <Object>[
        <String, Object>{
          ..._reference(),
          'nodes': <Object>[0]
        }
      ],
      'scene': 0
    };
    final result = await _read(json);
    final root =
        result.result.gltf.extensions[KHR_XMP_JSON_LD] as KhrXmpJsonLdGltf;
    final packet = root.packets[0];

    expect(result.context.errors, isEmpty);
    expect(packet.isUsed, isTrue);
    expect(packet.metadata['dc:title'], 'Example');
    expect(
        (result.result.gltf.asset.extensions[KHR_XMP_JSON_LD]
                as KhrXmpJsonLdReference)
            .packet,
        same(packet));
    expect(
        result.context.issues
            .where((issue) => issue.type == LinkError.unsupportedExtension),
        isEmpty);
  });

  test('restricted JSON-LD violations are diagnosed recursively', () async {
    final result = await _read(<String, Object>{
      'asset': <String, Object>{'version': '2.0'},
      'extensionsUsed': <Object>[KHR_XMP_JSON_LD],
      'extensions': <String, Object>{
        KHR_XMP_JSON_LD: <String, Object>{
          'packets': <Object>[
            <String, Object>{
              '@context': <String, Object>{
                'a': 'https://example.com/ns/',
                'alias': 'https://example.com/ns/',
                'term': 'a'
              },
              'expanded': <String, Object>{
                '@context': <String, Object>{'b': 'https://example.com/b/'},
                'a:values': <Object>[1, 2]
              }
            }
          ]
        }
      }
    });
    final codes = result.context.issues.map((issue) => issue.type.code).toSet();
    expect(codes, contains('KHR_XMP_JSON_LD_DUPLICATE_NAMESPACE'));
    expect(codes, contains('KHR_XMP_JSON_LD_INVALID_CONTEXT_VALUE'));
    expect(codes, contains('KHR_XMP_JSON_LD_INVALID_COMPACT_IRI'));
    expect(codes, contains('KHR_XMP_JSON_LD_LOCAL_CONTEXT'));
    expect(codes, contains('KHR_XMP_JSON_LD_UNWRAPPED_ARRAY'));
  });

  test('packets is required and must be nonempty', () async {
    for (final extension in <Map<String, Object>>[
      <String, Object>{},
      <String, Object>{'packets': <Object>[]}
    ]) {
      final result = await _read(<String, Object>{
        'asset': <String, Object>{'version': '2.0'},
        'extensionsUsed': <Object>[KHR_XMP_JSON_LD],
        'extensions': <String, Object>{KHR_XMP_JSON_LD: extension}
      });
      expect(result.context.errors, isNotEmpty);
    }
  });

  test('packet references resolve and unused packets are reported', () async {
    final result = await _read(<String, Object>{
      'asset': <String, Object>{'version': '2.0', ..._reference(2)},
      'extensionsUsed': <Object>[KHR_XMP_JSON_LD],
      'extensions': <String, Object>{
        KHR_XMP_JSON_LD: <String, Object>{
          'packets': <Object>[
            <String, Object>{
              '@context': <String, Object>{
                'dc': 'http://purl.org/dc/elements/1.1/'
              }
            },
            <String, Object>{
              '@context': <String, Object>{
                'dc': 'http://purl.org/dc/elements/1.1/'
              }
            }
          ]
        }
      }
    });
    final types = result.context.issues.map((issue) => issue.type);
    expect(types.where((type) => type == LinkError.unresolvedReference),
        hasLength(1));
    expect(types.where((type) => type == LinkError.unusedObject), hasLength(2));
  });

  test('permitted lists, sets, structures, and language values are valid',
      () async {
    final result = await _read(<String, Object>{
      'asset': <String, Object>{'version': '2.0', ..._reference()},
      'extensionsUsed': <Object>[KHR_XMP_JSON_LD],
      'extensions': <String, Object>{
        KHR_XMP_JSON_LD: <String, Object>{
          'packets': <Object>[
            <String, Object>{
              '@context': <String, Object>{
                'dc': 'http://purl.org/dc/elements/1.1/',
                'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
              },
              '@id': '',
              'dc:creator': <String, Object>{
                '@list': <Object>['A', 'B']
              },
              'dc:subject': <String, Object>{
                '@set': <Object>['one', 'two']
              },
              'dc:description': <String, Object>{
                '@type': 'rdf:Alt',
                'rdf:_1': <String, Object>{
                  '@language': 'en-us',
                  '@value': 'Description'
                }
              },
              'dc:title': <String, Object>{
                '@language': 'en',
                '@value': 'Title'
              },
              'dc:localized': <String, Object>{
                '@context': <String, Object>{'@language': 'fr'},
                'dc:value': 'Bonjour'
              }
            }
          ]
        }
      }
    });
    expect(result.context.errors, isEmpty);
  });

  test('invalid value objects and language alternatives are rejected',
      () async {
    final result = await _read(<String, Object>{
      'asset': <String, Object>{'version': '2.0'},
      'extensionsUsed': <Object>[KHR_XMP_JSON_LD],
      'extensions': <String, Object>{
        KHR_XMP_JSON_LD: <String, Object>{
          'packets': <Object>[
            <String, Object>{
              '@context': <String, Object>{
                'dc': 'http://purl.org/dc/elements/1.1/',
                'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
              },
              'dc:title': <String, Object>{
                '@type': 'rdf:Alt',
                'rdf:first': <String, Object>{'@language': 'EN-us', '@value': 3}
              },
              'dc:description': <String, Object>{'@value': 'missing language'},
              'dc:localized': <String, Object>{
                '@language': 'EN-us',
                '@value': 'Invalid tag'
              }
            }
          ]
        }
      }
    });
    final types = result.context.issues.map((issue) => issue.type);
    expect(types, contains(SemanticError.khrXmpJsonLdInvalidValueObject));
    expect(
        types, contains(SemanticError.khrXmpJsonLdInvalidLanguageAlternative));
    expect(types, contains(SemanticError.khrXmpJsonLdInvalidLanguageTag));
  });
}
