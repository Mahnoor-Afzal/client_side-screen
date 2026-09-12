importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDQP_4C2i-KvTJs7EeM_KyxShTP8NXTmqA",
  authDomain: "smart-legal-assistant-app.firebaseapp.com",
  projectId: "smart-legal-assistant-app",
  storageBucket: "smart-legal-assistant-app.firebasestorage.app",
  messagingSenderId: "636284975962",
  appId: "1:636284975962:web:6443c75163afe7c41c7945b70a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png",
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
