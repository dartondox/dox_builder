// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:dox_annotation/dox_annotation.dart';
import 'package:dox_builder/src/model_visitor.dart';
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
    String primaryKey =
        annotation.objectValue.getField('primaryKey')?.toStringValue() ?? 'id';

    final visitor = ModelVisitor();
    visitor.columns[primaryKey] = {
      'type': 'int?',
      'jsonKey': primaryKey,
      'beforeSave': null,
      'beforeGet': null,
    };
    element.visitChildren(visitor);
    String className = visitor.className;

    var r = _getRelationsCode(visitor);

    return """
    class ${className}Generator extends Model<$className> {
      @override
      String get primaryKey => '$primaryKey';

      ${_getTableNameSetter(tableName)}

      ${_primaryKeySetterAndGetter(primaryKey)}

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
        return {
          ${_getCodeForToMap(visitor)}
        };
      }
    }
    """;
  }

  _getRelationsCode(ModelVisitor visitor) {
    String content = '';
    String mapResultContent = '';
    String mapQueryContent = '';
    visitor.relations.forEach((key, value) {
      String getFunctionName = 'get${ucFirst(key.toString())}';
      String queryFunctionName = 'query${ucFirst(key.toString())}';

      String foreignKey = value['foreignKey'] != null
          ? ", foreignKey: '${value['foreignKey']}'"
          : '';

      String localKey =
          value['localKey'] != null ? ", localKey: '${value['localKey']}'" : '';

      String ownerKey =
          value['ownerKey'] != null ? ", ownerKey: '${value['ownerKey']}'" : '';

      String whereQuery = value['whereQuery'] != null
          ? ".whereRaw('${value['whereQuery']}')"
          : '';

      mapResultContent += "'$key': $getFunctionName,";
      mapQueryContent += "'$key': $queryFunctionName,";

      content += """
      static Future $getFunctionName(${visitor.className} i) async {
        var q = i.${value['relationType']}(i, () => ${value['model']}() $foreignKey $localKey $ownerKey,)$whereQuery;
        i.$key = isEmpty(i.$key) ? await q.end : i.$key;
        return i.$key;
      }

      static ${value['model']} $queryFunctionName(${visitor.className} i) {
        return i.${value['relationType']}(i, () => ${value['model']}() $foreignKey $localKey,)$whereQuery;
      }
      """;
    });
    return {
      'mapResultContent': mapResultContent,
      'mapQueryContent': mapQueryContent,
      'content': content,
    };
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
          setValue = "$className.$beforeGet($setValue)";
        }
      } else {
        setValue = "m['$jsonKey'] as ${values['type']}";
        if (beforeGet != null) {
          setValue = "$className.$beforeGet($setValue)";
        }
      }
      content += "..$filedName = $setValue\n";
    });
    return content += ';';
  }

  _getCodeForToMap(ModelVisitor visitor) {
    String content = '';
    String className = visitor.className;
    visitor.columns.forEach((filedName, values) {
      String? beforeSave = values['beforeSave'];
      String jsonKey = values['jsonKey'];
      String setValue = '';

      if (values['type'] == 'DateTime?') {
        setValue = "instance.$filedName?.toIso8601String()";
        if (beforeSave != null) {
          setValue = "$className.$beforeSave($setValue)";
        }
      } else {
        setValue = "instance.$filedName";
        if (beforeSave != null) {
          setValue = "$className.$beforeSave($setValue)";
        }
      }
      content += "'$jsonKey' : $setValue,\n";
    });
    return content;
  }

  ucFirst(String str) {
    return str.substring(0, 1).toUpperCase() + str.substring(1);
  }
}
