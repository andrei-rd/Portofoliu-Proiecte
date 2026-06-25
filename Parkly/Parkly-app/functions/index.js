const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Trimite o notificare push către toți utilizatorii care au un fcmToken valid.
 * Poate fi apelată doar de utilizatorii cu rolul 'admin'.
 */
exports.sendBroadcastNotification = functions.https.onCall(async (data, context) => {
    // 1. Securitate: Verificăm dacă cel care apelează este autentificat și este admin
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Trebuie să fii autentificat pentru a trimite notificări.');
    }

    // Verificăm rolul de admin în token sau în baza de date
    // Notă: Presupunem că rolul 'admin' este setat în Custom Claims sau verificăm Firestore
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();

    if (!userData || userData.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Doar administratorii pot lansa campanii de notificări.');
    }

    const title = data.title || 'Anunț Parkly';
    const body = data.body;

    if (!body) {
        throw new functions.https.HttpsError('invalid-argument', 'Mesajul notificării (body) este obligatoriu.');
    }

    // 2. Colectare Token-uri: Luăm toate token-urile salvate de aplicația mobilă
    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = [];

    usersSnapshot.forEach(doc => {
        const token = doc.data().fcmToken;
        if (token && typeof token === 'string') {
            tokens.push(token);
        }
    });

    if (tokens.length === 0) {
        return { success: true, message: 'Niciun dispozitiv înregistrat găsit.' };
    }

    // 3. Trimitere: Folosim messaging().sendEachForMulticast (varianta modernă)
    const message = {
        notification: {
            title: title,
            body: body,
        },
        android: {
            notification: {
                icon: 'stock_ticker_update',
                color: '#2563EB',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                channelId: 'high_importance_channel', // ASIGURĂ POP-UP PE ANDROID
                priority: 'high',
            },
        },
        tokens: tokens,
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);

        // Curățare opțională: am putea șterge token-urile care nu mai sunt valide
        // (response.responses.forEach...)

        console.log(`Notificări trimise cu succes: ${response.successCount}`);
        return {
            success: true,
            sentCount: response.successCount,
            failureCount: response.failureCount
        };
    } catch (error) {
        console.error('Eroare la trimiterea broadcast-ului:', error);
        throw new functions.https.HttpsError('internal', 'Eroare la serverul de notificări.');
    }
});
