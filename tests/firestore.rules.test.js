const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'running-dart-test';
const ENV = 'prod';
const rules = fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8');

let testEnv;

function envCollection(db, name) {
  return db.collection('environments').doc(ENV).collection(name);
}

async function setup() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
}

async function cleanup() {
  if (testEnv) {
    await testEnv.cleanup();
  }
}

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function seedUser(uid, data) {
  return testEnv.withSecurityRulesDisabled(async (context) => {
    await envCollection(context.firestore(), 'users').doc(uid).set({
      email: `${uid}@test.com`,
      displayName: 'Test User',
      qrCode: `RD-${uid}`,
      createdAt: new Date(),
      isActive: true,
      role: 'user',
      membershipStatus: 'active',
      membershipModality: 'community',
      ...data,
    });
  });
}

function seedPost(id, data) {
  return testEnv.withSecurityRulesDisabled(async (context) => {
    await envCollection(context.firestore(), 'posts').doc(id).set({
      authorName: 'Test Author',
      imageUrl: `https://example.com/${id}.jpg`,
      createdAt: new Date(),
      likesCount: 0,
      isHidden: false,
      ...data,
    });
  });
}

async function runTests() {
  await setup();

  try {
    await testEnv.clearFirestore();

    await assertSucceeds(
      envCollection(authedDb('user-new'), 'users').doc('user-new').set({
        email: 'new@test.com',
        displayName: 'New User',
        qrCode: 'RD-new',
        createdAt: new Date(),
        isActive: true,
        role: 'user',
        membershipStatus: 'active',
      }),
    );

    await assertFails(
      envCollection(authedDb('user-bad'), 'users').doc('user-bad').set({
        email: 'bad@test.com',
        displayName: 'Bad User',
        qrCode: 'RD-bad',
        createdAt: new Date(),
        isActive: true,
        role: 'admin',
        membershipStatus: 'active',
      }),
    );

    await seedUser('member-1', { role: 'member' });
    await seedUser('admin-1', { role: 'admin' });
    await seedUser('admin-2', { role: 'admin', displayName: 'Admin Two' });
    await seedUser('user-plain', { role: 'user', displayName: 'Plain User' });
    await seedUser('operator-1', {
      role: 'member',
      businessId: 'biz-001',
    });
    await seedUser('operator-2', {
      role: 'member',
      businessId: 'biz-001',
    });
    await seedUser('member-expired', {
      role: 'member',
      expiresAt: new Date(2020, 0, 1),
    });
    await seedUser('member-pending', {
      role: 'member',
      membershipStatus: 'pending',
    });
    await seedUser('member-disabled', {
      role: 'member',
      isActive: false,
    });
    await seedUser('user-nonmember', { role: 'user' });

    await assertSucceeds(
      envCollection(authedDb('user-new'), 'users').doc('user-new').get(),
    );

    await assertFails(
      envCollection(authedDb('user-new'), 'users').doc('member-1').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'users').doc('member-1').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'users').doc('admin-2').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'users').doc('user-plain').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'users').doc('member-1').get(),
    );

    await assertFails(
      envCollection(authedDb('admin-1'), 'users').doc('admin-1').update({
        role: 'member',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'users').doc('admin-1').update({
        displayName: 'Admin One Updated',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'users').doc('user-plain').update({
        role: 'member',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('user-plain'), 'users').doc('user-plain').update({
        photoUrl: 'https://example.com/user.jpg',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'users').doc('member-1').update({
        photoUrl: 'https://example.com/member.jpg',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'users').doc('admin-1').update({
        photoUrl: 'https://example.com/admin.jpg',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'users').doc('operator-1').update({
        photoUrl: 'https://example.com/operator.jpg',
      }),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'users').doc('user-plain').update({
        role: 'admin',
      }),
    );

    await assertFails(
      envCollection(authedDb('operator-1'), 'users').doc('user-new').get(),
    );

    // Ingreso manual: un operador resuelve a un miembro activo por su qrCode.
    // La query restringe los mismos campos que exige la regla (isActiveMember),
    // de modo que sea "demostrable" para operaciones list.
    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'users')
        .where('qrCode', '==', 'RD-member-1')
        .where('isActive', '==', true)
        .where('role', 'in', ['member', 'admin'])
        .where('membershipStatus', '==', 'active')
        .limit(1)
        .get(),
    );

    // Ingreso manual: un no-miembro simplemente no coincide (resultado vacio),
    // mismo comportamiento efectivo que el escaneo (no se puede leer su doc).
    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'users')
        .where('qrCode', '==', 'RD-user-plain')
        .where('isActive', '==', true)
        .where('role', 'in', ['member', 'admin'])
        .where('membershipStatus', '==', 'active')
        .limit(1)
        .get(),
    );

    // Sin las restricciones, la query no es demostrable y debe fallar.
    await assertFails(
      envCollection(authedDb('operator-1'), 'users')
        .where('qrCode', '==', 'RD-member-1')
        .limit(1)
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'news')
        .where('isPublished', '==', true)
        .get(),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await envCollection(context.firestore(), 'news').doc('news-published').set({
        title: 'Evento publicado',
        summary: 'Resumen',
        body: 'Cuerpo',
        eventDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublished: true,
      });
      await envCollection(context.firestore(), 'news').doc('news-draft').set({
        title: 'Evento borrador',
        summary: 'Resumen',
        body: 'Cuerpo',
        eventDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublished: false,
      });
    });

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'news').doc('news-published').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'news').doc('news-published').get(),
    );

    await assertFails(
      envCollection(authedDb('operator-1'), 'news').doc('news-draft').get(),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'news').doc('news-draft').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'news').doc('news-draft').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'news')
        .where('isPublished', '==', true)
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'news')
        .where('isPublished', '==', true)
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'news')
        .orderBy('eventDate', 'desc')
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'news').doc('news-new').set({
        title: 'Nuevo evento',
        summary: 'Resumen',
        body: 'Cuerpo',
        eventDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublished: true,
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'news').doc('news-blocked').set({
        title: 'Bloqueado',
        summary: 'Resumen',
        body: 'Cuerpo',
        eventDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublished: true,
      }),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await envCollection(context.firestore(), 'businesses').doc('biz-001').set({
        name: 'Cafe Test',
        description: 'Desc',
        address: 'Addr',
        phone: '123',
        hours: '9-5',
        category: 'café',
        benefits: ['10%'],
        discount: '10%',
      });
    });

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'businesses').doc('biz-001').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'businesses').doc('biz-new').set({
        name: 'New Biz',
        description: 'Desc',
        address: 'Addr',
        phone: '123',
        hours: '9-5',
        category: 'café',
        benefits: [],
        discount: '5%',
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'businesses').doc('biz-new-2').set({
        name: 'Blocked',
        description: 'Desc',
        address: 'Addr',
        phone: '123',
        hours: '9-5',
        category: 'café',
        benefits: [],
        discount: '5%',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'news').doc('news-published').delete(),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'news').doc('news-draft').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'businesses').doc('biz-001').delete(),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'businesses').doc('biz-new').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'visits').doc('visit-1').set({
        userId: 'member-1',
        businessId: 'biz-001',
        visitedAt: new Date(),
        memberDisplayName: 'Member One',
        memberQrCode: 'RD-member-1',
        scannedByUserId: 'operator-1',
        validationResult: 'approved',
      }),
    );

    await assertFails(
      envCollection(authedDb('operator-1'), 'visits').doc('visit-self').set({
        userId: 'operator-1',
        businessId: 'biz-001',
        visitedAt: new Date(),
        memberDisplayName: 'Operator One',
        memberQrCode: 'RD-operator-1',
        scannedByUserId: 'operator-1',
        validationResult: 'approved',
      }),
    );

    await assertFails(
      envCollection(authedDb('operator-1'), 'visits').doc('visit-colleague').set({
        userId: 'operator-2',
        businessId: 'biz-001',
        visitedAt: new Date(),
        memberDisplayName: 'Operator Two',
        memberQrCode: 'RD-operator-2',
        scannedByUserId: 'operator-1',
        validationResult: 'approved',
      }),
    );

    await assertFails(
      envCollection(authedDb('operator-1'), 'visits').doc('visit-2').set({
        userId: 'member-1',
        businessId: 'biz-other',
        visitedAt: new Date(),
        memberDisplayName: 'Member One',
        memberQrCode: 'RD-member-1',
        scannedByUserId: 'operator-1',
        validationResult: 'approved',
      }),
    );

    // Aprobar exige que el socio pueda recibir beneficios de verdad: si la
    // comprobación viviera solo en el cliente, bastaría con saltárselo.
    for (const scannedUserId of [
      'member-expired',
      'member-pending',
      'member-disabled',
      'user-nonmember',
    ]) {
      await assertFails(
        envCollection(authedDb('operator-1'), 'visits')
          .doc(`visit-approved-${scannedUserId}`)
          .set({
            userId: scannedUserId,
            businessId: 'biz-001',
            visitedAt: new Date(),
            memberDisplayName: 'Scanned Member',
            memberQrCode: `RD-${scannedUserId}`,
            scannedByUserId: 'operator-1',
            validationResult: 'approved',
          }),
      );

      // Rechazar sí se puede: el intento fallido queda registrado.
      await assertSucceeds(
        envCollection(authedDb('operator-1'), 'visits')
          .doc(`visit-rejected-${scannedUserId}`)
          .set({
            userId: scannedUserId,
            businessId: 'biz-001',
            visitedAt: new Date(),
            memberDisplayName: 'Scanned Member',
            memberQrCode: `RD-${scannedUserId}`,
            scannedByUserId: 'operator-1',
            validationResult: 'rejected',
          }),
      );
    }

    await assertSucceeds(
      envCollection(authedDb('operator-1'), 'visits').doc('visit-1').get(),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'visits').doc('visit-1').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').set({
        userId: 'member-1',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'pending',
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-other').set({
        userId: 'user-plain',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'pending',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'payments').doc('pay-admin').set({
        userId: 'member-1',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'approved',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'payments').doc('pay-admin').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'payments').doc('pay-admin').get(),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await envCollection(context.firestore(), 'payments').doc('pay-other-user').set({
        userId: 'user-plain',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'approved',
      });
    });

    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-other-user').get(),
    );

    // Al dueño solo le queda reemplazar el comprobante mientras siga pendiente.
    await assertSucceeds(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').update({
        receiptUrl: 'https://example.com/receipt.jpg',
      }),
    );

    // Aprobarse el pago a sí mismo sería saltarse la revisión de membresía.
    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').update({
        status: 'approved',
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').update({
        amount: 0,
      }),
    );

    // El historial de pagos es la auditoría: no lo borra su dueño.
    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').delete(),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-other-user').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'payments').doc('pay-self').update({
        status: 'approved',
      }),
    );

    // Ya revisado, ni siquiera el comprobante se puede cambiar.
    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').update({
        receiptUrl: 'https://example.com/other.jpg',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'payments').doc('pay-self').delete(),
    );

    await seedUser('coach-1', { role: 'coach' });

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'club_settings')
        .doc('training_schedule')
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('coach-1'), 'club_settings')
        .doc('training_schedule')
        .set({
          location: 'Jelen Tenka',
          venue: 'Quito',
          sections: [],
        }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'club_settings')
        .doc('training_schedule')
        .set({
          location: 'Hack',
          venue: 'Hack',
          sections: [],
        }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'club_settings')
        .doc('training_schedule')
        .set({
          location: 'Jelen Tenka',
          venue: 'Quito',
          sections: [],
        }),
    );

    await seedPost('post-visible', { authorId: 'member-1' });
    await seedPost('post-hidden', {
      authorId: 'member-1',
      isHidden: true,
      hiddenAt: new Date(),
      hiddenReason: 'spam',
      hiddenBy: 'admin-1',
    });

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'posts').doc('post-mine').set({
        authorId: 'member-1',
        authorName: 'Member One',
        imageUrl: 'https://example.com/post.jpg',
        createdAt: new Date(),
        isHidden: false,
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-impostor').set({
        authorId: 'user-plain',
        authorName: 'Plain User',
        createdAt: new Date(),
        isHidden: false,
      }),
    );

    // Nadie nace moderado: publicar no puede traer los campos de moderación.
    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-premoderated').set({
        authorId: 'member-1',
        authorName: 'Member One',
        createdAt: new Date(),
        isHidden: true,
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-prehidden').set({
        authorId: 'member-1',
        authorName: 'Member One',
        createdAt: new Date(),
        isHidden: false,
        hiddenAt: new Date(),
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('user-plain'), 'posts').doc('post-visible').get(),
    );

    // Ocultar tiene que valer para lectura, no solo para escritura.
    await assertFails(
      envCollection(authedDb('user-plain'), 'posts').doc('post-hidden').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'posts').doc('post-hidden').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'posts').doc('post-hidden').get(),
    );

    // El feed filtra en la consulta porque un list que devuelva una oculta
    // falla entero.
    await assertSucceeds(
      envCollection(authedDb('user-plain'), 'posts')
        .where('isHidden', '==', false)
        .get(),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'posts').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'posts').get(),
    );

    // El autor sí puede pedir las suyas completas: es donde se entera de que le
    // ocultaron una y por qué.
    await assertSucceeds(
      envCollection(authedDb('member-1'), 'posts')
        .where('authorId', '==', 'member-1')
        .get(),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'posts')
        .where('authorId', '==', 'member-1')
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('user-plain'), 'posts')
        .where('authorId', '==', 'member-1')
        .where('isHidden', '==', false)
        .get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'posts').doc('post-visible').update({
        caption: 'Rodada del domingo',
      }),
    );

    // El contador de likes lo escribe la Cloud Function, no el autor.
    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-visible').update({
        likesCount: 9999,
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-visible').update({
        recentLikes: [{ userId: 'user-plain', displayName: 'Plain User' }],
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-visible').update({
        authorId: 'user-plain',
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-visible').update({
        createdAt: new Date(2020, 0, 1),
      }),
    );

    // Nadie se auto-restaura una publicación oculta.
    await assertFails(
      envCollection(authedDb('member-1'), 'posts').doc('post-hidden').update({
        isHidden: false,
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'posts').doc('post-visible').update({
        isHidden: true,
        hiddenAt: new Date(),
        hiddenReason: 'offensive',
        hiddenBy: 'admin-1',
      }),
    );

    // Al administrador le toca moderar, no reescribir lo que otro publicó.
    await assertFails(
      envCollection(authedDb('admin-1'), 'posts').doc('post-visible').update({
        caption: 'Editado por el admin',
      }),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'posts').doc('post-mine').delete(),
    );

    // El administrador oculta; borrar sigue siendo del autor.
    await assertFails(
      envCollection(authedDb('admin-1'), 'posts').doc('post-mine').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'posts').doc('post-mine').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'follows').doc('member-1_user-plain').set({
        followerId: 'member-1',
        followedId: 'user-plain',
        createdAt: new Date(),
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'follows').doc('user-plain_member-1').set({
        followerId: 'user-plain',
        followedId: 'member-1',
        createdAt: new Date(),
      }),
    );

    // Solo el dueño del seguimiento puede deshacerlo.
    await assertFails(
      envCollection(authedDb('user-plain'), 'follows')
        .doc('member-1_user-plain')
        .delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'follows')
        .doc('member-1_user-plain')
        .delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'post_likes')
        .doc('post-visible_member-1')
        .set({
          postId: 'post-visible',
          userId: 'member-1',
          postAuthorId: 'member-1',
          createdAt: new Date(),
        }),
    );

    // El id del documento es lo que impide dar dos veces el mismo me gusta.
    await assertFails(
      envCollection(authedDb('member-1'), 'post_likes')
        .doc('otro-id')
        .set({
          postId: 'post-visible',
          userId: 'member-1',
          postAuthorId: 'member-1',
          createdAt: new Date(),
        }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'post_likes')
        .doc('post-visible_user-plain')
        .set({
          postId: 'post-visible',
          userId: 'user-plain',
          postAuthorId: 'member-1',
          createdAt: new Date(),
        }),
    );

    // `postAuthorId` va desnormalizado y el borrado de cuenta se fía de él, así
    // que no puede apuntar a alguien que no escribió la publicación.
    await assertFails(
      envCollection(authedDb('user-plain'), 'post_likes')
        .doc('post-visible_user-plain')
        .set({
          postId: 'post-visible',
          userId: 'user-plain',
          postAuthorId: 'user-plain',
          createdAt: new Date(),
        }),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'post_likes')
        .doc('post-visible_user-plain')
        .set({
          postId: 'post-visible',
          userId: 'user-plain',
          createdAt: new Date(),
        }),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'blocks').doc('member-1_user-plain').set({
        blockerId: 'member-1',
        blockedId: 'user-plain',
        createdAt: new Date(),
      }),
    );

    // A quién bloqueaste es asunto tuyo: nadie más lo lee.
    await assertFails(
      envCollection(authedDb('user-plain'), 'blocks').doc('member-1_user-plain').get(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'post_reports').doc('report-1').set({
        postId: 'post-visible',
        reportedByUserId: 'member-1',
        createdAt: new Date(),
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'post_reports').doc('report-2').set({
        postId: 'post-visible',
        reportedByUserId: 'user-plain',
        createdAt: new Date(),
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'public_profiles').doc('member-1').set({
        username: 'member1',
        displayName: 'Member One',
        updatedAt: new Date(),
      }),
    );

    // El perfil público es de su dueño: nadie más lo edita salvo un admin.
    await assertFails(
      envCollection(authedDb('user-plain'), 'public_profiles').doc('member-1').set({
        username: 'secuestrado',
        displayName: 'Member One',
        updatedAt: new Date(),
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('admin-1'), 'public_profiles').doc('member-1').update({
        displayName: 'Member One (moderado)',
      }),
    );

    await assertSucceeds(
      envCollection(authedDb('user-plain'), 'public_profiles').doc('member-1').get(),
    );

    await assertFails(
      envCollection(testEnv.unauthenticatedContext().firestore(), 'public_profiles')
        .doc('member-1')
        .get(),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'public_profiles').doc('member-1').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'usernames').doc('member1').set({
        userId: 'member-1',
        createdAt: new Date(),
      }),
    );

    // La reserva es lo que garantiza que un usuario sea único, así que no se
    // puede apuntar a otra cuenta ni reasignar la que ya está tomada.
    await assertFails(
      envCollection(authedDb('user-plain'), 'usernames').doc('plain1').set({
        userId: 'member-1',
        createdAt: new Date(),
      }),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'usernames').doc('member1').update({
        userId: 'user-plain',
      }),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'usernames').doc('member1').update({
        userId: 'member-1',
      }),
    );

    await assertFails(
      envCollection(authedDb('user-plain'), 'usernames').doc('member1').delete(),
    );

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'usernames').doc('member1').delete(),
    );

    console.log('All Firestore rules tests passed.');
  } finally {
    await cleanup();
  }
}

runTests().catch((error) => {
  console.error(error);
  process.exit(1);
});
