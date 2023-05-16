// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:dox_annotation/dox_annotation.dart';
import 'package:dox_builder/src/model_visitor.dart';
import 'package:dox_builder/src/util.dart';
import 'package:source_gen/source_gen.dart';

class DoxModelBuilder extends GeneratorForAnnotation<DoxModel> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    String? tableName =
        annotation.objectValue.getField('table')?.toStringValue();
    String primaryKeySnakeCase =
        annotation.objectValue.getField('primaryKey')?.toStringValue() ?? 'id';
    String primaryKey = toCamelCase(primaryKeySnakeCase);
    String? createdAt =
        annotation.objectValue.getField('createdAt')?.toStringValue();
    String? updatedAt =
        annotation.objectValue.getField('updatedAt')?.toStringValue();

    final visitor = ModelVisitor();

    visitor.columns.addAll({
      primaryKey: {
        'type': 'int?',
        'jsonKey': primaryKeySnakeCase,
        'beforeSave': null,
        'beforeGet': null,
      }
    });

    element.visitChildren(visitor);

    if (createdAt != null) {
      visitor.columns.addAll({
        'createdAt': {
          'type': 'DateTime?',
          'jsonKey': createdAt,
          'beforeSave': null,
          'beforeGet': null,
        }
      });
    }
    if (updatedAt != null) {
      visitor.columns.addAll({
        'updatedAt': {
          'type': 'DateTime?',
          'jsonKey': updatedAt,
          'beforeSave': null,
          'beforeGet': null,
        }
      });
    }
    String className = visitor.className;
    String createdColumn = createdAt != null ? "'$createdAt'" : 'null';
    String updatedColumn = updatedAt != null ? "'$updatedAt'" : 'null';

    var r = _getRelationsCode(visitor);
    var map = _getCodeForToMap(visitor);

    return """
    class ${className}Generator extends Model<$className> {
      @override
      String get primaryKey => '$primaryKeySnakeCase';

      @override
      Map<String, dynamic> get timestampsColumn => {
        'created_at': $createdColumn,
        'updated_at': $updatedColumn,
      };

      ${_getTableNameSetter(tableName)}

      ${_primaryKeySetterAndGetter(primaryKey)}

      $className get newQuery => $className();

      @override
      List get preloadList => [
        ${r['eagerLoad']}
      ];

      @override
      Map<String, Function> get relationsResultMatcher => {
          ${r['mapResultContent']}
      };

      @override
      Map<String, Function> get relationsQueryMatcher => {
          ${r['mapQueryContent']}
      };

      ${r['content']}

      @override
      $className fromMap(Map<String, dynamic> m) => $className()
        ${_getCodeForFromMap(visitor)}

      @override
      Map<String, dynamic> convertToMap(i) {
        $className instance = i as $className;
        Map<String, dynamic> map = {
          ${map['jsonMapper']}
        };
        ${map['parseContent']}
        return map;
      }
    }
    """;
  }

  _getRelationsCode(ModelVisitor visitor) {
    String content = '';
    String mapResultContent = '';
    String mapQueryContent = '';
    String eagerLoad = '';
    visitor.relations.forEach((key, value) {
      String getFunctionName = 'get${ucFirst(key.toString())}';
      String queryFunctionName = 'query${ucFirst(key.toString())}';

      String onQuery = value['onQuery'] != null
          ? ", onQuery: ${visitor.className}.${value['onQuery']}"
          : '';

      mapResultContent += "'$key': $getFunctionName,";
      mapQueryContent += "'$key': $queryFunctionName,";

      eagerLoad += value['eager'] == true ? "'$key'," : "";

      content += """
      static Future $getFunctionName(List list) async {
        var result = await get${value['relationType']}<${value['model']}>($queryFunctionName(list), list);
        for (${visitor.className} i in list) {
          i.$key = result[i.tempIdValue.toString()];
          if (list.length == 1) {
            return i.$key;
          }
        }
      }

      static ${value['model']}? $queryFunctionName(List list) {
        return ${lcFirst(value['relationType'])}<${value['model']}>(list, 
          () => ${value['model']}() 
          ${_getParamKeyValue(value, 'foreignKey')}
          ${_getParamKeyValue(value, 'localKey')}
          ${_getParamKeyValue(value, 'relatedKey')}
          ${_getParamKeyValue(value, 'pivotForeignKey')}
          ${_getParamKeyValue(value, 'pivotRelatedForeignKey')}
          ${_getParamKeyValue(value, 'pivotTable')}
          $onQuery,
        );
      }
      """;
    });

    return {
      'mapResultContent': mapResultContent,
      'mapQueryContent': mapQueryContent,
      'content': content,
      'eagerLoad': eagerLoad,
    };
  }

  _getParamKeyValue(value, key) {
    return value[key] != null ? ", $key: '${value[key]}'" : '';
  }

  _getTableNameSetter(tableName) {
    return tableName != null
        ? """
      @override
      String get tableName => 'blog';
    """
        : '';
  }

  _primaryKeySetterAndGetter(primaryKey) {
    return """
      int? get $primaryKey => tempIdValue;
      
      set $primaryKey(val) => tempIdValue = val;
    """;
  }

  _getCodeForFromMap(ModelVisitor visitor) {
    String content = '';
    String className = visitor.className;

    visitor.columns.forEach((filedName, values) {
      String jsonKey = values['jsonKey'];
      String? beforeGet = values['beforeGet'];
      String setValue = '';

      if (values['type'] == 'DateTime?') {
        setValue = """m['$jsonKey'] == null
              ? null
              : DateTime.parse(m['$jsonKey'] as String)
          """;
        if (beforeGet != null) {
          setValue = "$className.$beforeGet(m)";
        }
      } else {
        setValue = "m['$jsonKey'] as ${values['type']}";
        if (beforeGet != null) {
          setValue = "$className.$beforeGet(m)";
        }
      }
      content += "..$filedName = $setValue\n";
    });
    return content += ';';
  }

  _getCodeForToMap(ModelVisitor visitor) {
    String jsonMapper = '';
    String parseContent = '';
    String className = visitor.className;
    visitor.columns.forEach((filedName, values) {
      String? beforeSave = values['beforeSave'];
      String jsonKey = values['jsonKey'];
      String setValue = '';

      if (values['type'] == 'DateTime?') {
        setValue = "instance.$filedName?.toIso8601String()";
      } else {
        setValue = "instance.$filedName";
      }

      if (beforeSave != null) {
        parseContent = "map['$jsonKey'] = $className.$beforeSave(map);";
      }
      jsonMapper += "'$jsonKey' : $setValue,\n";
    });

    return {
      'jsonMapper': jsonMapper,
      'parseContent': parseContent,
    };
  }
}
