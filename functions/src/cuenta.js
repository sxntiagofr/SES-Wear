// Eliminación completa de la cuenta (derecho de supresión, Ley 1581 de 2012).
// Borra, en este orden:
//   1. Firestore: users/{uid} y TODAS sus subcolecciones (prendas, outfits,
//      conversaciones, planificador, colecciones, uso...).
//   2. Storage: todas las fotos en users/{uid}/.
//   3. Firebase Authentication: la cuenta.
// Se hace en el servidor porque desde la app no se pueden borrar subcolecciones
// de forma recursiva y borrar la cuenta exigiría volver a iniciar sesión.

export async function eliminarDatosDeUsuario({ db, bucket, auth, logger = console }, uid) {
  if (typeof uid !== "string" || !uid) throw new Error("uid inválido");

  await db.recursiveDelete(db.collection("users").doc(uid));

  try {
    await bucket.deleteFiles({ prefix: `users/${uid}/` });
  } catch (error) {
    // Si no tenía fotos o el bucket no responde, igual se borra la cuenta.
    logger.warn?.("No se pudieron borrar todas las fotos", error);
  }

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
  }
}
