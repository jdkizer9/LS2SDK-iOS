//
//  LS2Client.swift
//  LS2SDK
//
//  Created by James Kizer on 12/26/17.
//

import UIKit
import Alamofire
import OMHClient

open class LS2Client: NSObject {
    
    public struct SignInResponse {
        public let authToken: String
    }
    
    let baseURL: String
    let dispatchQueue: DispatchQueue?
    
    public init(baseURL: String, dispatchQueue: DispatchQueue? = nil) {
        self.baseURL = baseURL
        self.dispatchQueue = dispatchQueue
        super.init()
    }
    
    open func processAuthResponse(isRefresh: Bool, completion: @escaping ((SignInResponse?, Error?) -> ())) -> ((DataResponse<Any>) -> ()) {
        
        return { jsonResponse in
            
            debugPrint(jsonResponse)
            //check for lower level errors
            if let error = jsonResponse.result.error as? NSError {
                if error.code == NSURLErrorNotConnectedToInternet {
                    completion(nil, LS2ClientError.unreachableError(underlyingError: error))
                    return
                }
                else {
                    completion(nil, LS2ClientError.otherError(underlyingError: error))
                    return
                }
            }
            
            //check for our errors
            //credentialsFailure
            guard let response = jsonResponse.response else {
                completion(nil, LS2ClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if let response = jsonResponse.response,
                response.statusCode == 502 {
                debugPrint(jsonResponse)
                completion(nil, LS2ClientError.badGatewayError)
                return
            }

            //check for malformed body
            guard jsonResponse.result.isSuccess,
                let json = jsonResponse.result.value as? [String: Any],
                let authToken = json["token"] as? String else {
                    completion(nil, LS2ClientError.malformedResponse(responseBody: jsonResponse.result.value))
                    return
            }
            
            let signInResponse = SignInResponse(authToken: authToken)
            completion(signInResponse, nil)
            
        }
        
    }
    
    open func signIn(username: String, password: String, completion: @escaping ((SignInResponse?, Error?) -> ())) {
        
        let urlString = "\(self.baseURL)/auth/token"
        let parameters = [
            "username": username,
            "password": password
        ]
        
        let request = Alamofire.request(
            urlString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default)
        
        request.responseJSON(queue: self.dispatchQueue, completionHandler: self.processAuthResponse(isRefresh: false, completion: completion))
        
    }
    
    open func validateSample(sample: OMHDataPoint) -> Bool {
        
        let sampleDict = sample.toDict()
        return JSONSerialization.isValidJSONObject(sampleDict)
        
    }
    
    open func postSample(
        sampleDict: OMHDataPointDictionary,
        token: String,
        completion: @escaping ((Bool, Error?) -> ())) {
        
        self.postJSONSample(sampleDict: sampleDict, token: token, completion: completion)
        
    }
    
    private func postJSONSample(sampleDict: OMHDataPointDictionary, token: String, completion: @escaping ((Bool, Error?) -> ())) {
        let urlString = "\(self.baseURL)/dataPoints"
        let headers = ["Authorization": "Token \(token)", "Accept": "application/json"]
        let params = sampleDict
        
        guard JSONSerialization.isValidJSONObject(sampleDict) else {
            completion(false, LS2ClientError.invalidDatapoint)
            return
        }
        
        let request = Alamofire.request(
            urlString,
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            headers: headers)
        
        let reponseProcessor: (DataResponse<Any>) -> () = self.processJSONResponse(completion: completion)
        
        request.responseJSON(queue: self.dispatchQueue, completionHandler: reponseProcessor)
        
    }
    
    private func processJSONResponse(completion: @escaping ((Bool, Error?) -> ())) -> (DataResponse<Any>) -> () {
        
        return { jsonResponse in
            //check for actually success
            
            debugPrint(jsonResponse)
            
            switch jsonResponse.result {
            case .success:
                print("Validation Successful")
                guard let response = jsonResponse.response else {
                    completion(false, LS2ClientError.unknownError)
                    return
                }
                
                switch (response.statusCode) {
                case 201:
                    completion(true, nil)
                    return
                    
                case 400:
                    completion(false, LS2ClientError.invalidDatapoint)
                    return
                    
                case 401:
                    completion(false, LS2ClientError.invalidAuthToken)
                    return
                
                case 409:
                    completion(false, LS2ClientError.dataPointConflict)
                    return
                    
                case 500:
                    completion(false, LS2ClientError.serverError)
                    return
                    
                case 502:
                    completion(false, LS2ClientError.badGatewayError)
                    return

                default:
                    
                    if let error = jsonResponse.result.error {
                        completion(false, error)
                        return
                    }
                    else {
                        completion(false, LS2ClientError.malformedResponse(responseBody: jsonResponse))
                        return
                    }
                    
                }
                
                
            case .failure(let error):
                let nsError = error as NSError
                if nsError.code == NSURLErrorNotConnectedToInternet {
                    completion(false, LS2ClientError.unreachableError(underlyingError: nsError))
                    return
                }
                else {
                    completion(false, LS2ClientError.otherError(underlyingError: nsError))
                    return
                }
            }
        }
        
    }
    
    

}
