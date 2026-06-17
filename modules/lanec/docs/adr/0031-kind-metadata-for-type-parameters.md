# Kind metadata for type parameters

Lane2 type parameter metadata carries kind information even though v1 supports only the `Type` kind. Recording kinds now keeps the checked type object model ready for future higher-kinded type parameters without changing every type-parameter identity and type-object API later.
