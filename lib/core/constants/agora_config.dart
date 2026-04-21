class AgoraConfig {
  static const String appId = "4736b1a519264c6e813e4e28bf75db9d"; 
  
  // Set this to empty string to enable Backend Token Fetching
  static const String tempToken = ""; 
  
  // Direct HTTP bypass URL to skip App Check/Auth issues
  static const String tokenUrl = "https://us-central1-hellochat-e8965.cloudfunctions.net/getSecureAgoraTokenHttp"; 
}
