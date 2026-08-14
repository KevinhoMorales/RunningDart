/// Resultado de una consulta paginada. [cursor] es opaco: solo tiene sentido
/// pasárselo de vuelta al mismo servicio que lo emitió (p. ej. un
/// `DocumentSnapshot` de Firestore).
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<T> items;
  final bool hasMore;

  /// Cursor para pedir la página siguiente (más antigua en feeds DESC, o más
  /// vieja en comentarios ASC + `limitToLast`).
  final Object? cursor;
}
