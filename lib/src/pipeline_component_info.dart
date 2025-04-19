// lib/src/pipeline_component_info.dart

class PipelineComponentInfo {
  final int order;
  final String description;
  final Type componentType;
  final bool isHandler;

  PipelineComponentInfo({
    required this.order,
    required this.description,
    required this.componentType,
    this.isHandler = false,
  });

  @override
  String toString() =>
      'Order: $order, Type: $componentType, Desc: "$description"${isHandler ? " (Handler)" : ""}';
}
