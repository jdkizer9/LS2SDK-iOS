//
//  LS2ParticipantAccountGeneratorTokenStepViewController.swift
//  LS2SDK
//
//  Created by James Kizer on 11/15/18.
//

import UIKit
import ResearchSuiteExtensions
import ResearchKit

open class LS2ParticipantAccountGeneratorTokenStepViewController: RSLoginStepViewController {
    
    override open func handleButtonTap(identityResult: ORKResult?, passwordResult: ORKResult?, completion: @escaping ActionCompletion) {
        
        guard let step = self.step as? LS2ParticipantAccountGeneratorTokenStep,
            let token = (passwordResult as? ORKTextQuestionResult)?.answer as? String else {
                
                //            self.logInSuccessful = false
                let message: String = "Invalid configuration. Please contact support."
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Log in failed", message: message, preferredStyle: UIAlertController.Style.alert)
                    
                    // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                    let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                        (result : UIAlertAction) -> Void in
                        
                    }
                    
                    alertController.addAction(okAction)
                    self.present(alertController, animated: true, completion: {
                        completion(false)
                    })
                }
                
                return
        }
        
        self.isLoading = true
        step.manager.generateParticipantAccountWithToken(generatorId: step.generatorID, token: token) { (error) in
            //if we got and error and its not already have credentials, throw error
            
            switch error {
                
            case .none:
                fallthrough
            case .some(LS2ManagerErrors.hasCredentials):
                //if no error OR we alreay have credentials, try to log in with credentials
                step.manager.signInWithCredentials(forceSignIn: true, completion: { (error) in
                    
                    if error == nil {
                        self.loggedIn = true
                        completion(true)
                    }
                    else {
                        self.loggedIn = false
                        let message: String = "An error occurred. Pleas try again."
                        DispatchQueue.main.async {
                            let alertController = UIAlertController(title: "Log in failed", message: message, preferredStyle: UIAlertController.Style.alert)
                            
                            // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                                (result : UIAlertAction) -> Void in
                                
                            }
                            
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: {
                                completion(false)
                            })
                        }
                        return
                    }
                })
                
            default:
                
                self.isLoading = false
                let message: String = "Unable to create log in credentials."
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Log in failed", message: message, preferredStyle: UIAlertController.Style.alert)
                    
                    // Replace UIAlertActionStyle.Default by UIAlertActionStyle.default
                    let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
                        (result : UIAlertAction) -> Void in
                        
                    }
                    
                    alertController.addAction(okAction)
                    self.present(alertController, animated: true, completion: {
                        completion(false)
                    })
                }
                
            }
        }
        
    }
    
}
