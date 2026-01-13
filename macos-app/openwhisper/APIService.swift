//
//  APIService.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private init() {}
    
    func sendTranscriptionRequest(audioBase64: String, apiUrl: String, authToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: apiUrl) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["audio_base64": audioBase64]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                completion(.success(responseString))
            } else {
                completion(.failure(NSError(domain: "Invalid response", code: -1, userInfo: nil)))
            }
        }
        
        task.resume()
    }
}
