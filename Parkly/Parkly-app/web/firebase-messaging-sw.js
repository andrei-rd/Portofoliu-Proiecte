importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAgbFCIdDu00fQsB7HZkabrA6pwLiRUo3M",
  appId: "1:208306661715:web:56361706a62f1e546099a6",
  messagingSenderId: "208306661715",
  projectId: "parkly-69906",
  authDomain: "parkly-69906.firebaseapp.com",
  storageBucket: "parkly-69906.firebasestorage.app",
  measurementId: "G-DHVJ607PLH",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png",
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
