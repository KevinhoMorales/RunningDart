const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'running-dart-test';
const rules = fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8');

let testEnv;

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
    await context.firestore().collection('users').doc(uid).set({
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
      authedDb('user-new').collection('users').doc('user-new').set({
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
      authedDb('user-bad').collection('users').doc('user-bad').set({
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
      authedDb('user-new').collection('users').doc('user-new').get(),
    );

    await assertFails(
      authedDb('user-new').collection('users').doc('member-1').get(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('users').doc('member-1').get(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('users').doc('admin-2').get(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('users').doc('user-plain').get(),
    );

    await assertSucceeds(
      authedDb('operator-1').collection('users').doc('member-1').get(),
    );

    await assertFails(
      authedDb('admin-1').collection('users').doc('admin-1').update({
        role: 'member',
      }),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('users').doc('admin-1').update({
        displayName: 'Admin One Updated',
      }),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('users').doc('user-plain').update({
        role: 'member',
      }),
    );

    await assertSucceeds(
      authedDb('user-plain').collection('users').doc('user-plain').update({
        photoUrl: 'https://example.com/user.jpg',
      }),
    );

    await assertSucceeds(
      authedDb('member-1').collection('users').doc('member-1').update({
        photoUrl: 'https://example.com/member.jpg',
      }),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('users').doc('admin-1').update({
        photoUrl: 'https://example.com/admin.jpg',
      }),
    );

    await assertSucceeds(
      authedDb('operator-1').collection('users').doc('operator-1').update({
        photoUrl: 'https://example.com/operator.jpg',
      }),
    );

    await assertFails(
      authedDb('user-plain').collection('users').doc('user-plain').update({
        role: 'admin',
      }),
    );

    await assertFails(
      authedDb('operator-1').collection('users').doc('user-new').get(),
    );

    await assertSucceeds(
      authedDb('member-1')
        .collection('news')
        .where('isPublished', '==', true)
        .get(),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('news').doc('news-published').set({
        title: 'Evento publicado',
        summary: 'Resumen',
        body: 'Cuerpo',
        eventDate: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
        isPublished: true,
      });
      await context.firestore().collection('news').doc('news-draft').set({
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
      authedDb('member-1').collection('news').doc('news-published').get(),
    );

    await assertSucceeds(
      authedDb('operator-1').collection('news').doc('news-published').get(),
    );

    await assertFails(
      authedDb('operator-1').collection('news').doc('news-draft').get(),
    );

    await assertFails(
      authedDb('member-1').collection('news').doc('news-draft').get(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('news').doc('news-draft').get(),
    );

    await assertSucceeds(
      authedDb('member-1')
        .collection('news')
        .where('isPublished', '==', true)
        .get(),
    );

    await assertSucceeds(
      authedDb('operator-1')
        .collection('news')
        .where('isPublished', '==', true)
        .get(),
    );

    await assertSucceeds(
      authedDb('admin-1')
        .collection('news')
        .orderBy('eventDate', 'desc')
        .get(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('news').doc('news-new').set({
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
      authedDb('member-1').collection('news').doc('news-blocked').set({
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
      await context.firestore().collection('businesses').doc('biz-001').set({
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
      authedDb('member-1').collection('businesses').doc('biz-001').get(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('businesses').doc('biz-new').set({
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
      authedDb('member-1').collection('businesses').doc('biz-new-2').set({
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
      authedDb('admin-1').collection('news').doc('news-published').delete(),
    );

    await assertFails(
      authedDb('member-1').collection('news').doc('news-draft').delete(),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('businesses').doc('biz-001').delete(),
    );

    await assertFails(
      authedDb('member-1').collection('businesses').doc('biz-new').delete(),
    );

    await assertSucceeds(
      authedDb('operator-1').collection('visits').doc('visit-1').set({
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
      authedDb('operator-1').collection('visits').doc('visit-self').set({
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
      authedDb('operator-1').collection('visits').doc('visit-colleague').set({
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
      authedDb('operator-1').collection('visits').doc('visit-2').set({
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
      authedDb('operator-1').collection('visits').doc('visit-1').get(),
    );

    await assertFails(
      authedDb('member-1').collection('visits').doc('visit-1').get(),
    );

    await assertSucceeds(
      authedDb('member-1').collection('payments').doc('pay-self').set({
        userId: 'member-1',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'pending',
      }),
    );

    await assertFails(
      authedDb('member-1').collection('payments').doc('pay-other').set({
        userId: 'user-plain',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'pending',
      }),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('payments').doc('pay-admin').set({
        userId: 'member-1',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'approved',
      }),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('payments').doc('pay-admin').get(),
    );

    await assertSucceeds(
      authedDb('member-1').collection('payments').doc('pay-admin').get(),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('payments').doc('pay-other-user').set({
        userId: 'user-plain',
        modality: 'official',
        amount: 5,
        paidAt: new Date(),
        status: 'approved',
      });
    });

    await assertFails(
      authedDb('member-1').collection('payments').doc('pay-other-user').get(),
    );

    await seedUser('coach-1', { role: 'coach' });

    await assertSucceeds(
      authedDb('member-1').collection('club_settings').doc('training_schedule').get(),
    );

    await assertSucceeds(
      authedDb('coach-1').collection('club_settings').doc('training_schedule').set({
        location: 'Jelen Tenka',
        venue: 'Quito',
        sections: [],
      }),
    );

    await assertFails(
      authedDb('member-1').collection('club_settings').doc('training_schedule').set({
        location: 'Hack',
        venue: 'Hack',
        sections: [],
      }),
    );

    await assertSucceeds(
      authedDb('admin-1').collection('club_settings').doc('training_schedule').set({
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
