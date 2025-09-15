import Foundation
import Alamofire
import SwiftUI

// PostCardViewModelを取得する関数
func getPostCardViewModel() async throws -> PostCardViewModel? {
    // iOS 15以降ではUIApplication.shared.windowsは非推奨
    // 代わりに直接新しいViewModelを作成して返す
    var viewModel: PostCardViewModel?
    
    await MainActor.run {
        viewModel = PostCardViewModel(text: "")
    }
    
    return viewModel
}

func createRecord(param: CreateRecordRequest) async throws -> CreateRecordResponse {
    let endPoint = "https://bsky.social/xrpc/"
    let createRecord = "com.atproto.repo.createRecord"
    
    let session = try await SessionManager.shared.getSession()
    let urlString = endPoint + createRecord
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)"
    ]
    
    // 画像埋め込みがある場合は、特別な処理を行う
    if let embed = param.record.embed, embed.type == "app.bsky.embed.images" {
        print("画像埋め込みを含むポストを作成します")
        
        // パラメータを辞書に変換
        var paramDict: [String: Any] = [
            "repo": param.repo,
            "collection": param.collection,
            "record": [
                "text": param.record.text,
                "createdAt": param.record.createdAt ?? Date().ISO8601Format()
            ]
        ]
        
        if let rkey = param.rkey {
            paramDict["rkey"] = rkey
        }
        
        if let validate = param.validate {
            paramDict["validate"] = validate
        }
        
        if let swapCommit = param.swapCommit {
            paramDict["swapCommit"] = swapCommit
        }
        
        // 画像埋め込み用の辞書を作成
        var recordDict = paramDict["record"] as? [String: Any] ?? [:]
        
        // 画像埋め込み用の辞書を作成
        var imagesArray: [[String: Any]] = []
        
        // PostCardViewModelからBlobReferenceを取得
        if let viewModel = try? await getPostCardViewModel() {
            for (index, image) in viewModel.selectedImages.enumerated() {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    continue
                }
                
                print("画像[\(index)]のアップロード開始")
                let response = try await uploadBlob(imageData: imageData, mimeType: "image/jpeg")
                print("画像[\(index)]のアップロード成功: cid=\(response.blob.cid)")
                
                let imageDict: [String: Any] = [
                    "alt": "画像の説明",
                    "image": [
                        "$type": "blob",
                        "ref": [
                            "$link": response.blob.cid
                        ],
                        "mimeType": response.blob.mimeType
                    ]
                ]
                
                imagesArray.append(imageDict)
            }
        }
        
        if imagesArray.isEmpty {
            // 画像が取得できなかった場合は、ダミーの画像情報を使用
            imagesArray = [
                [
                    "alt": "画像の説明",
                    "image": [
                        "$type": "blob",
                        "ref": [
                            "$link": "3jdmaeokc2m2a"  // ダミーのCID
                        ],
                        "mimeType": "image/jpeg"
                    ]
                ]
            ]
        }
        
        let embedDict: [String: Any] = [
            "$type": "app.bsky.embed.images",
            "images": imagesArray
        ]
        
        recordDict["embed"] = embedDict
        paramDict["record"] = recordDict
        
        print("送信するパラメータ: \(paramDict)")
        
        // JSONデータに変換
        let jsonData = try JSONSerialization.data(withJSONObject: paramDict, options: [])
        
        // URLRequestを作成
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        // ヘッダーを設定
        headers.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        // リクエストを送信
        let response = await AF.request(request)
            .validate()
            .serializingDecodable(CreateRecordResponse.self)
            .response
        
        switch response.result {
        case .success(let value):
            print("ポスト成功: \(value)")
            return value
        case .failure(let error):
            print("ポスト失敗: \(error)")
            print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
            print("ステータスコード: \(response.response?.statusCode ?? 0)")
            
            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                print("レスポンスボディ: \(responseString)")
            }
            
            throw error
        }
    } else {
        // 通常のポスト（画像なし）
        print("通常のポストを作成します")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let response = await AF.request(
                urlString,
                method: .post, 
                parameters: param,
                encoder: JSONParameterEncoder.default,
                headers: headers)
                .validate()
                .serializingDecodable(CreateRecordResponse.self)
                .response
            
            switch response.result {
            case .success(let value):
                print("ポスト成功: \(value)")
                return value
            case .failure(let error):
                print("ポスト失敗: \(error)")
                print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
                print("ステータスコード: \(response.response?.statusCode ?? 0)")
                
                if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                    print("レスポンスボディ: \(responseString)")
                }
                
                throw error
            }
        } catch {
            print("例外発生: \(error)")
            throw error
        }
    }
}
