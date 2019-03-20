//
//  ViewController.swift
//  HealthRecordsSample
//
//  Created by Nobuhiro Takahashi on 2019/03/20.
//  Copyright © 2019年 Nobuhiro Takahashi. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {
    let myHealthStore = HKHealthStore()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let clinicalSets: Set<HKObjectType> = NSSet(array: [
            HKObjectType.clinicalType(forIdentifier: .allergyRecord)!,      // アレルギー
            HKObjectType.clinicalType(forIdentifier: .conditionRecord)!,    // 体調
            HKObjectType.clinicalType(forIdentifier: .immunizationRecord)!, // 免疫
            HKObjectType.clinicalType(forIdentifier: .labResultRecord)!,    // 検査結果
            HKObjectType.clinicalType(forIdentifier: .medicationRecord)!,   // 薬物(薬物治療中の情報など)
            HKObjectType.clinicalType(forIdentifier: .procedureRecord)!,    // 手順
            HKObjectType.clinicalType(forIdentifier: .vitalSignRecord)!     // バイタルサイン(血圧、脈拍、呼吸など)
        ]) as! Set<HKObjectType>
        
        // clinicalType は全て読み込み限定となります
        myHealthStore.getRequestStatusForAuthorization(toShare: Set(),
                                                       read: clinicalSets) {
                                                        (status, error) in
            if let e = error {
                print(e.localizedDescription)
                return
            }
            
            print(status.rawValue)
            switch status {
            case .unknown:
                // 「不明な状態」
                fallthrough
            case .shouldRequest:
                // 「リクエストが必要」
                // iOS の Settings → Language & Region の Region が「United States」でないと対応していないからか、
                // 現時点では処理を sucess = true、error = nil で無言で進行していってしまう
                
                // かつ初回の認証ではここで NSHealthRequiredReadAuthorizationTypeIdentifiers に即したエラーがでるが、
                // 次回起動時に getRequestStatusForAuthorization の結果が .unnecessary がになってしまって
                // このステートメントにたどり着かない..？ HealthKit のバグな気がする...？
                self.myHealthStore.requestAuthorization(toShare: nil,
                                                        read: clinicalSets) {
                                                            (success, error) in
                    if let e = error {
                        print(e.localizedDescription)
                        return
                    }
                    if success {
                        self.queryAllergyRecords()
                    }
                }
            case .unnecessary:
                // 「リクエストが不要」
                self.queryAllergyRecords()
            default:
                print("status 不一致")
            }
        }
        
    }
    
    func queryAllergyRecords() {
        let allergyType = HKObjectType.clinicalType(forIdentifier: .allergyRecord)!
        let allergyQuery = HKSampleQuery(sampleType: allergyType,
                                         predicate: nil,
                                         limit: HKObjectQueryNoLimit,
                                         sortDescriptors: nil) {
                                            (query, samples, error) in
            if let e = error {
                print(e.localizedDescription)
            }
            guard let actualSamples = samples else {
                print(error?.localizedDescription ?? "nil")
                return
            }
            let allergySamples = actualSamples as? [HKClinicalRecord]
            
            // FHIR の JSON データをパースする
            guard let fhirRecord = allergySamples?.first?.fhirResource else {
                print("FHIR レコードが見つかりませんでした")
                return
            }
            do {
                let jsonDictionary = try JSONSerialization.jsonObject(with: fhirRecord.data,
                                                                      options: [])
                print(jsonDictionary)
            }
            catch let error {
                print("FHIR データのパースに失敗")
                print(error.localizedDescription)
            }
        }
        
        myHealthStore.execute(allergyQuery)
    }
}
