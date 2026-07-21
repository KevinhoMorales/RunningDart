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

    await assertSucceeds(
      envCollection(authedDb('member-1'), 'payments').doc('pay-self').delete(),
    );

    await assertFails(
      envCollection(authedDb('member-1'), 'payments').doc('pay-other-user').delete(),
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

    console.log('All Firestore rules tests passed.');
  } finally {
    await cleanup();
  }
}

runTests().catch((error) => {
  console.error(error);
  process.exit(1);
});
