/// English interface strings. This is the reference table: every other
/// language falls back to these keys when a translation is missing.
const Map<String, String> stringsEn = {
  'appName': 'Clinical AI',
  'tagline': 'Explainable symptom analysis',

  // Disclaimers - wording fixed by the medical safety requirements
  'disclaimer':
      'This application provides general health information and clinical decision support. It does not replace professional medical diagnosis or treatment.',
  'disclaimerShort':
      'This tool provides general information and clinical decision support. It does not provide a definitive diagnosis.',
  'urgentNotice':
      'Some selected symptoms may require prompt medical attention. Please consult a qualified healthcare professional.',
  'notInKnowledgeBase':
      'Information is not available in the current knowledge base.',
  'possibleMatch':
      'This condition is a possible match based on the selected symptoms.',

  // Home
  'heroTitle': 'Know your symptoms. Understand your health.',
  'heroSubtitle':
      'Select your symptoms and receive AI-assisted, explainable health information based on your symptoms.',
  'selectSymptoms': 'Select your symptoms',
  'searchSymptoms': 'Search symptoms',
  'searchHint': 'Type a symptom, for example: headache',
  'available': 'Available',
  'selected': 'Selected',
  'clearAll': 'Clear all',
  'analyze': 'Analyze symptoms',
  'analyzing': 'Analyzing',
  'noSymptomsSelected': 'Select at least one symptom to run an analysis.',
  'noMatches': 'No symptoms match that search.',
  'selectedCount': '{n} selected',
  'symptomLimitReached': 'You can select up to {n} symptoms.',

  // Results
  'results': 'Analysis results',
  'resultNumber': 'Result {n}',
  'symptomMatch': 'Symptom match',
  'modelConfidence': 'Model confidence',
  'symptomMatchCaption':
      "Share of this condition's dataset symptoms that you selected.",
  'modelConfidenceCaption':
      'Classifier output. Not a medically validated probability.',
  'matchedSymptoms': 'Matched symptoms',
  'unmatchedSymptoms': 'Not associated',
  'explanation': 'Explanation',
  'viewDetails': 'View details',
  'noResults': 'No candidate conditions could be ranked.',
  'excludedSymptoms': 'Not in the dataset and excluded from this analysis',

  // Disease detail
  'overview': 'Overview',
  'commonSymptoms': 'Common symptoms',
  'precautions': 'Precautions',
  'whenToSeekCare': 'When to seek professional care',
  'severity': 'Severity',
  'supportCaption':
      "The percentage is how often each symptom appears in this condition's records in the prediction dataset. Highlighted symptoms are ones you selected.",

  // Medical Q&A

  // History
  'history': 'History',
  'historyTitle': 'Your saved analyses',
  'historyEmpty': 'Analyses you run will be saved here.',
  'startAnalysis': 'Start an analysis',
  'topPrediction': 'Top result',
  'delete': 'Delete',
  'clearHistory': 'Clear history',
  'confirmDelete': 'Delete this saved analysis?',
  'confirmClear': 'Delete every saved analysis? This cannot be undone.',
  'deleted': 'Analysis deleted.',
  'historyCleared': 'History cleared.',

  // Profile
  'profile': 'Profile',
  'name': 'Name',
  'email': 'Email',
  'preferredLanguage': 'Preferred language',
  'accountCreated': 'Account created',
  'editProfile': 'Edit profile',
  'saveChanges': 'Save changes',
  'profileUpdated': 'Profile updated.',
  'cancel': 'Cancel',
  'logout': 'Sign out',
  'confirmLogout': 'Sign out of Clinical AI?',
  'privacyNote':
      'Clinical AI stores your account details and the analyses you run. It does not store medical records or documents.',

  // Auth
  'login': 'Sign in',
  'loginSubtitle': 'Sign in to run an analysis and see your saved results.',
  'register': 'Create account',
  'registerSubtitle': 'Your saved analyses are tied to this account.',
  'password': 'Password',
  'confirmPassword': 'Confirm password',
  'passwordHint': 'At least 8 characters, including letters and numbers.',
  'forgotPassword': 'Forgot your password?',
  'forgotPasswordSubtitle': "Enter your email and we'll send a reset link.",
  'resetPassword': 'Reset password',
  'resetPasswordSubtitle': 'Choose a new password for your account.',
  'sendResetLink': 'Send reset link',
  'newPassword': 'New password',
  'resetToken': 'Reset token',
  'noAccount': 'No account yet?',
  'haveAccount': 'Already have an account?',
  'passwordResetDone': 'Password updated. You can sign in now.',

  // Voice
  'voiceInput': 'Speak symptoms',
  'listening': 'Listening',
  'stopListening': 'Stop',
  'voiceUnsupported':
      'Voice input is not available on this device. Type your symptoms instead.',
  'voiceHeard': 'Heard: {text}',
  'voiceNoMatch':
      'Nothing in that matched a symptom in the dataset. Try the search box.',
  'voiceAdded': 'Added {n} symptom(s) from what you said.',

  // Common
  'home': 'Home',
  'language': 'Language',
  'romanise': 'Show Roman transliteration',
  'loading': 'Loading',
  'retry': 'Try again',
  'back': 'Back',
  'close': 'Close',
  'ok': 'OK',
  'somethingWentWrong': 'Something went wrong.',
  'devMode': 'Development mode',
  'thinInputTitle': 'Add more symptoms for a reliable result',
  'thinInputBody':
      'You selected {n} symptom(s). Conditions in this dataset have between 4 and 17 symptoms, so a short list matches many conditions at once and the scores below stay low. Adding two or three more usually separates them clearly.',
  'addMoreSymptoms': 'Add more symptoms',
  'lowConfidenceNote':
      'Low scores here mean the selected symptoms fit several conditions, not that any one of them is ruled out.',
  'listenToResults': 'Listen to the results',
  'stopAudio': 'Stop',
  'audioUnavailable':
      'Audio playback is not available for this language on this device.',
  'spokenResult':
      'Result {n}. {disease}. {matched} of your {total} symptoms match this condition. Symptom match {match} percent. Model confidence {confidence} percent.',
  'spokenIntro':
      'Analysis results. {n} possible conditions, most likely first.',
  'spokenDisclaimer':
      'This is general health information, not a diagnosis. Please consult a qualified doctor.',
  'selectAtLeast': 'Select at least {n} symptoms. {r} more needed.',
  'symptomRange': 'Select {min} to {max} symptoms.',
  'sortBy': 'Order by',
  'suggestedSymptoms': 'Commonly reported together',
  'suggestedCaption':
      'Symptoms often recorded alongside your selection in the dataset. Tap to add. This is not a medical suggestion.',
};
