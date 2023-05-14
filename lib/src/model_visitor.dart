import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';

class ModelVisitor extends SimpleElementVisitor<void> {
  String className = '';
  Map<String, Map<String, dynamic>> columns = {};

  Map<String, Map<String, dynamic>> relations = {};

  @override
  void visitConstructorElement(ConstructorElement element) {
    final returnType = element.returnType.toString();
    className = returnType.replaceFirst('*', '');
  }

  @override
  void visitFieldElement(FieldElement element) {
    var isColumn = element.metadata
        .where((m) => m.element?.displayName == 'Column')
        .isNotEmpty;

    var isRelation = element.metadata
        .where((m) =>
            ['HasOne', 'HasMany', 'BelongsTo'].contains(m.element?.displayName))
        .isNotEmpty;

    String elementKey = element.name;

    if (isRelation == true) {
      ElementAnnotation metaData = element.metadata.first;
      DartObject? object = metaData.computeConstantValue();
      var whereQuery = object?.getField('whereQuery')?.toStringValue();

      String? model = object
          ?.getField('model')
          ?.toTypeValue()
          .toString()
          .replaceFirst('*', '');

      String? foreignKey = object?.getField('foreignKey')?.toStringValue();

      String? localKey = object?.getField('localKey')?.toStringValue();

      relations[element.name] = {
        'relationType': lcFirst(metaData.element?.displayName),
        'model': model?.replaceFirst('?', ''),
        'dataType': element.type.toString().replaceFirst('*', ''),
        'localKey': localKey,
        'foreignKey': foreignKey,
        'whereQuery': whereQuery
      };
    }

    if (isColumn) {
      DartObject? object = element.metadata.first.computeConstantValue();
      var key = object?.getField('name')?.toStringValue();
      elementKey = key ?? element.name;

      String? beforeSave =
          object?.getField('beforeSave')?.toFunctionValue()?.displayName;

      String? beforeGet =
          object?.getField('beforeGet')?.toFunctionValue()?.displayName;

      columns[element.name] = {
        'type': element.type.toString().replaceFirst('*', ''),
        'jsonKey': elementKey,
        'beforeSave': beforeSave,
        'beforeGet': beforeGet,
      };
    }
  }

  lcFirst(String? str) {
    if (str == null) {
      return '';
    }
    return str.substring(0, 1).toLowerCase() + str.substring(1);
  }
}
