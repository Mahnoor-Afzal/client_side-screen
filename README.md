# Smart Legal Assistant App ⚖️🤖

Smart Legal Assistant App ek modern Flutter-based application hai jo clients aur lawyers ke darmiyan gap ko khatam karti hai. Is app mein advanced AI capability (via OpenRouter API), real-time messaging, comprehensive document management (Documents Vault), hearings tracking, aur multi-lawyer team coordination ko intehai professional and refined tareeqe se integrate kiya gaya hai.

---

## 🚀 App Overviews & User Roles

App do (2) major modules/roles par mushtamil hai:
1. **Client Portal:** Jahaan users apne legal issues ko AI chatbot se discuss kar sakte hain, recommended lawyers find kar sakte hain, case requests bhej sakte hain, aur case ki live tracking kar sakte hain.
2. **Lawyer Portal:** Jahaan lawyers incoming case requests (with AI Analysis) ko manage karte hain, client se communication karte hain, hearings add karte hain, associate/supporting lawyers ke sath teams banate hain, aur closed cases ke reviews track karte hain.

---

## 🌟 Key Features

### 1. 🤖 AI Chatbot (Intelligent Legal Consultant)
- **Automatic Classification:** Client apna legal issue input karta hai, AI backend par automatically judge karta hai ke issue legal hai ya nahi (using JSON structured prompt mapping).
- **AI Card Generation:** Agar issue legal hai, toh automatic Priority Level (High/Medium/Low), Suggested Case Type, Category, Best Lawyer type, aur Next Recommended Step generate hota hai.
- **Direct Referral:** Chatbot screen se hi single-click par client us recommended category ke lawyers ki list par redirect ho jata hai jismein AI report sath attach hoti hai.

### 2. 📂 Case Requests & Smart Filtering
- **Two Request Types:** Client "Consultation" ya "Suit Filing" ki request bhej sakta hai.
- **Lawyer-Side Filtered Hub:** Lawyer ke paas pending requests tabbed organization aur advanced filter ke sath aati hain jahan se wo Client Name ya Category se search kar sakta hai.
- **Conditional AI Report Visibility:** Lawyer ko AI Analysis report **sirf tabhi** show hoti hai jab client ne chatbot ke through consult kiya ho, taake direct request clean and concise rahein.

### 3. 💬 Real-Time Communication & Chat
- **Instant Messaging:** Case request accept hote hi client aur lawyer ke darmiyan instant chat room initialization ho jati hai.
- **Team Chats:** Agar ek case par multiple lawyers kaam kar rahe hain, toh automatic group/team chat open ho jati hai jahan client aur saare supporting lawyers ba-asani collab kar sakte hain.

### 4. 🗄️ Documents Vault (Secure File Sharing)
- **Role-Based Separation:** Pure documents vault ko "RECEIVED" aur "SENT" tabs mein divide kiya gaya hai.
- **Sent Tab:** Users (Client ya Lawyer) dwara upload kiye gaye saare files track hote hain.
- **Received Tab:** Client ko lawyer ke bheje gaye documents dikhte hain. Supporting lawyers ke join karne par unke shared documents bhi strictly right access control ke sath received tab mein propagate hote hain.

### 5. 📅 Hearing & Vakalatnama Management
- **Live Hearing Logs:** Lawyer active cases mein direct custom date, time, court room, aur notes ke sath hearings schedule kar sakta hai, jo client dashboard par live sync hoti hain.
- **Vakalatnama Forms:** Direct digital form submission for legal representation authorizations.

### 6. 🤝 Team Coordination & Associate Lawyers
- **Add Team Members:** Main lead lawyer kisi bhi case mein email search karke kisi doosre verified associate lawyer ko team mein add kar sakta hai.
- **Shared Access:** Team member add hote hi associate lawyer ke dashboard par "Coordinated Cases" tab active ho jata hai aur wo us case ke chat aur documents tak full access pa leta hai.

### 7. ⭐ Case Closure & Rating System
- **Formal Resolution:** Case complete hone par lawyer dashboard se "Close Case" trigger karta hai.
- **Feedback Loop:** Case close hote hi client ke paas Rating aur Review submission ka option unlock ho jata hai. Submissions ke baad lawyer un reviews ko apne "Closed Cases" section mein live dekh sakta hai.

---

## 🔄 End-to-End Application Flows

### 📲 Flow 1: Client Consultation & AI Assistance
1. Client **Chatbot Screen** par jata hai aur apni query type karta hai.
2. AI query analyze karke decision box (JSON Format) return karta hai.
3. Client **"Consult Recommended Lawyers"** par click karta hai.
4. Client kisi verified lawyer ko choose karke **Request Send** kar deta hai. 
5. Backend par `suit_a_file_request` ya `consultation_request` collection mein status `Pending` ke sath entry ho jati hai aur lawyer ko instantaneous push notification milta hai.

### 💼 Flow 2: Lawyer Acceptance & Team Setup
1. Lawyer **Case Requests Screen** open karta hai.
2. Agar request chatbot ke through aayi thi, toh lawyer ko purple **AI Analysis Report Container** visible hota hai.
3. Lawyer **"Accept"** button press karta hai:
   - Request status badal kar `accepted` ho jata hai.
   - Ek naya document `chat` collection mein create ho jata hai jismein `users: [clientId, lawyerId]` map hote hain.
4. Lawyer Active Case Card se **"Add Team Member"** select karke associate lawyer ki email dalta hai.
5. Email verify hote hi `coordination` collection active ho jati hai, aur `chat` group mein new user append ho jata hai.

### 🏛️ Flow 3: Hearings, Vault, and Closure
1. Lawyer case ke andar **"Hearings"** chip par click karke nayi hearing save karta hai.
2. Client aur Lawyer **Documents Vault** open karke case related PDF/Images exchange karte hain.
3. Case final argument ke baad Lawyer **"Close Case"** par click karta hai.
4. Client portal par status updated milta hai, client 5-star rating scale aur text review fill karta hai.
5. Lawyer ke **Closed Cases Screen** par wo specific record ratings aur italicized text reviews ke sath list ho jata hai.

---

## 🛠️ Tech Stack & Architecture

- **Frontend Framework:** Flutter (Dart)
- **State Management & Async UI:** StatefulWidgets, StreamBuilder (for real-time Firestore synchronization), FutureBuilder.
- **Database:** Firebase Cloud Firestore (NoSQL hierarchical structure)
- **Authentication:** Firebase Auth (Email & Password sign-in)
- **Push Notifications:** Firebase Cloud Messaging (FCM) & `flutter_local_notifications` via a centralized `NotificationHelper`.
- **AI Integration:** HTTP REST Client targeting OpenRouter API with custom strict system instructions.

---

## 📁 Key Database Collections Reference

- `users` / `lawyers`: Stores profile information, roles, specializations, and account details.
- `suit_a_file_request` / `consultation_request`: Real-time tracking of case information, parameters (`status`, `aiAnalysis`, `assignedLawyers`, `teamNames`, `rating`, `review`).
- `chat`: Direct and group text communication logs containing array of authorized user UIDs.
- `coordination`: Tracks shared cases amongst multi-lawyer councils.
- `notifications`: Holds real-time notifications for unread status monitoring on dashboards.

---

## ⚙️ How to Run the Project

1. **Prerequisites:** Make sure Flutter SDK is installed (`flutter doctor`).
2. **Clone and Navigate:**
   ```bash
   cd client_side-screen
   ```
3. **Install Dependencies:**
   ```bash
   flutter pub get
   ```
4. **Firebase Configuration:** Ensure your `google-services.json` (for Android) or `FirebaseOptions` setup is configured properly for your active Firebase Project.
5. **AI Key Setup:** Open `lib/client_chatbot_screen.dart` and update the `_apiKey` variable with your valid OpenRouter Token.
6. **Launch:**
   ```bash
   flutter run
   ```
