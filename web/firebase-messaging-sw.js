importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: '{{FIREBASE_API_KEY}}',
  appId: '{{FIREBASE_APP_ID}}',
  projectId: '{{FIREBASE_PROJECT_ID}}',
  messagingSenderId: '{{FIREBASE_MESSAGING_SENDER_ID}}',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || '일자리';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
