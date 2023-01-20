//
//  MediaUploader.swift
//  iOS file scanning prototype
//
//  Created by Ashley Davis on 15/1/2023.
//

import Foundation
import CryptoKit
import Photos
import UIKit
import CoreLocation
import Contacts

struct FileDetails : Codable {
  let name: String
  let localAssetid: String
  let contentType: String
  var hash: String?
  var uploaded: Bool
  let width: Int
  let height: Int
  var location: String?
}

struct MediaUploader {
  
  //
  // Errors thrown during photo operations.
  //
  public enum Error: Swift.Error {
    // Thrown if a full size image URL is missing
    case missingFullSizeImageURL
    case unknown
  }
    
  //
  // Gets the data for the asset.
  //
  // - Parameter completion: a closure which gets a `Result` (`Data` on `success` or `Error` on `failure`)
  //
  public func getAssetData(asset: PHAsset) async throws -> Data {
    
    let options = PHImageRequestOptions()
    // options.isNetworkAccessAllowed = true
    
    if #available(iOS 13, macOS 10.15, tvOS 13, *) {
      let imageManager = PHImageManager.default()
      return try await withCheckedThrowingContinuation { continuation in
        imageManager.requestImageDataAndOrientation(for: asset, options: options, resultHandler: { data, _, _, info in
          if let error = info?[PHImageErrorKey] as? Error {
            continuation.resume(with: .failure(error))
          } else if let data = data {
            continuation.resume(with: .success(data))
          } else {
            continuation.resume(with: .failure(Error.unknown))
          }
        })
      }
    } else {
      // Fallback on earlier versions
      return try await withCheckedThrowingContinuation { continuation in
        asset.requestContentEditingInput(with: nil) { contentEditingInput, _ in
          guard let fullSizeImageURL = contentEditingInput?.fullSizeImageURL else {
            continuation.resume(with: .failure(Error.missingFullSizeImageURL))
            return
          }
          
          do {
            let data = try Data(contentsOf: fullSizeImageURL)
            continuation.resume(with: .success(data))
          } catch {
            continuation.resume(with: .failure(error))
          }
        }
      }
    }
  }
    
  //
  // Errors thrown during permission requests
  // Like `PHAuthorizationStatus` but without `unknown` case
  //
  public enum PermissionError: Swift.Error {
    // Thrown if the permission was denied
    case denied
    // Thrown if the permission could not be determined
    case notDetermined
    // Thrown if the access was restricted
    case restricted
    // Thrown if an unknown error occurred
    case unknown
  }
  
  //
  // Requests the user's permission to the photo library
  //
  // - Parameter completion: a closure which gets a `Result` (`Void` on `success` and `Error` on `failure`)
  //
  private func requestPermission() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      let handler: (PHAuthorizationStatus) -> Void = { authorizationStatus in
        DispatchQueue.main.async {
          switch authorizationStatus {
          case .authorized, .limited:
            continuation.resume(with: .success(()))
          case .denied:
            continuation.resume(with: .failure(PermissionError.denied))
          case .restricted:
            continuation.resume(with: .failure(PermissionError.restricted))
          case .notDetermined:
            continuation.resume(with: .failure(PermissionError.notDetermined))
          @unknown default:
            continuation.resume(with: .failure(PermissionError.unknown))
          }
        }
      }
      
      if #available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, *) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handler)
      } else {
        PHPhotoLibrary.requestAuthorization(handler)
      }
    }
  }
  
  //
  // Computes the hash of the data.
  //
  private func computeHash(data : Data) -> String {
    // https://www.hackingwithswift.com/example-code/cryptokit/how-to-calculate-the-sha-hash-of-a-string-or-data-instance
    let hashed = SHA256.hash(data: data)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
  }

  //
  // Uploads an asset to the backend.
  //
  private func checkFileUploaded(hash: String) async throws -> Bool {
    let url = URL(string: "http://192.168.20.14:3000/check-asset?hash=" + hash)!
    var request = URLRequest(url: url)
    request.httpMethod = "GET";
    
    // https://wwdcbysundell.com/2021/using-async-await-with-urlsession/
    let (_, response) = try await URLSession.shared.data(from: url)
    return (response as! HTTPURLResponse).statusCode == 200
  }
  
  //
  // Uploads an asset to the backend.
  //
  private func uploadFile(_ contentType: String, _ fileDetails: FileDetails, _ assetData: Data) async throws {
    let url = URL(string: "http://192.168.20.14:3000/asset")!
    let session = URLSession.shared
    var request = URLRequest(url: url)
    request.httpMethod = "POST";
    request.setValue(contentType, forHTTPHeaderField: "content-type")
    request.setValue(fileDetails.name, forHTTPHeaderField: "file-name")
    request.setValue(String(fileDetails.width), forHTTPHeaderField: "width")
    request.setValue(String(fileDetails.height), forHTTPHeaderField: "height")
    request.setValue(fileDetails.hash, forHTTPHeaderField: "hash")
    //
    //todo: This should be handled in the backen
    //      Ideally will use multipart form data to upload location, exif data, thumbnail and full asset.
    //
    request.setValue(fileDetails.location, forHTTPHeaderField: "location")
    request.httpBody = assetData
    
    //todo: convert this to the async version!
    try await withCheckedThrowingContinuation { continuation in
      let task = session.dataTask(with: request as URLRequest, completionHandler: { data1, response, error in
        
        guard error == nil else {
          return
        }
        
        guard let data1 = data1 else {
          return
        }
        
        do {
          if let json = try JSONSerialization.jsonObject(with: data1, options: .mutableContainers) as? [String: Any] {
            print("Got response ^^^^^^^^^^^^")
            print(json)
            
            continuation.resume(with: .success(()))
          }
        } catch let error {
          print(error.localizedDescription)
        }
      })
      
      task.resume()
    }
  }
  
  public typealias ReverseGeocodeCompletion = (Result<String?, Swift.Error>) -> Void
  
  //
  // Reverse geocodes a particular location.
  //
  private func reverseGeocode(location: CLLocation) async throws -> String {
    let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
    let placemark = placemarks[0] as CLPlacemark
    var addressString = CNPostalAddressFormatter().string(from: placemark.postalAddress!)
    addressString = addressString
      .split(separator: "\n")
      .map({ line in line.trimmingCharacters(in: .whitespacesAndNewlines) })
          .joined(separator: ", ")
    return addressString
  }
  
  public enum AssetPropertiesError: Swift.Error {
          /// Thrown if a CIImage instance could not be created
          case couldNotCreateCIImage
          /// Thrown if a full size image URL is missing
          case missingFullSizeImageURL
          /// Thrown if the camera produced an unsupported result
          case unsupportedCameraResult
  }
  
  public typealias AssetPropertiesCompletion = (Result<[String : Any], AssetPropertiesError>) -> Void
  
  //
  // Retreive properties (e.g. exif data) for the asset.
  //
  private func getAssetProperties(_ asset: PHAsset) async throws -> [String : Any] {
    let contentEditingOptions = PHContentEditingInputRequestOptions()
    contentEditingOptions.isNetworkAccessAllowed = true
    
    return try await withCheckedThrowingContinuation { continuation in
      asset.requestContentEditingInput(with: contentEditingOptions) { contentEditingInput, _ in
        guard let fullSizeImageURL = contentEditingInput?.fullSizeImageURL else {
          continuation.resume(with: .failure(AssetPropertiesError.missingFullSizeImageURL))
          return
        }
        
        guard let fullImage = CIImage(contentsOf: fullSizeImageURL) else {
          continuation.resume(with: .failure(AssetPropertiesError.couldNotCreateCIImage))
          return
        }
        
        continuation.resume(with: .success(fullImage.properties))
      }
    }
  }
  
  private func uploadAsset(assetLocalId: String, uploadList: UserDefaults) async throws -> Void {
    let jsonString = uploadList.string(forKey: assetIdPrefix + assetLocalId)!
    var fileDetails = try JSONDecoder().decode(FileDetails.self, from: jsonString.data(using: .utf8)!)
    if fileDetails.uploaded {
      print("Asset already marked as uploaded " + assetLocalId)
      return
    }
    
    var contentType = fileDetails.contentType;
    let options = PHFetchOptions()
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalId], options: options)
    let asset = fetchResult.firstObject!
    var assetData = try await getAssetData(asset: asset)

    if contentType == "image/heic" {
      //
      // Convert heic files to jpg.
      //
      contentType = "image/jpg";

      let image = UIImage(data: assetData)!
      assetData = image.jpegData(compressionQuality: 1)!
    }
    
    //
    // Test to resize image to create a thumbnail.
    // Eventually this should be uploaded in addition to the original asset.
    //
    // https://www.advancedswift.com/resize-uiimage-no-stretching-swift/
    //
    let image = UIImage(data: assetData)!
    let targetSize = CGSize(width: 100, height: 100)

    // Compute the scaling ratio for the width and height separately
    let widthScaleRatio = targetSize.width / image.size.width //TODO: I feel like there is something wrong with this formula. One of the dimensions should come out as 100, but both are bigger!
    let heightScaleRatio = targetSize.height / image.size.height

    // To keep the aspect ratio, scale by the smaller scaling ratio
    let scaleFactor = min(widthScaleRatio, heightScaleRatio)

    // Multiply the original image’s dimensions by the scale factor
    // to determine the scaled image size that preserves aspect ratio
    let scaledImageSize = CGSize(
        width: image.size.width * scaleFactor,
        height: image.size.height * scaleFactor
    )
    
    let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
    let scaledImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: scaledImageSize))
    }
    
    assetData = scaledImage.jpegData(compressionQuality: 0.5)!

    if fileDetails.hash == nil {
      // Compute a hash for the file.
      fileDetails.hash = computeHash(data: assetData);

      // Update record in local storage.
      let jsonData = try JSONEncoder().encode(fileDetails)
      uploadList.set(String(data: jsonData, encoding: .utf8)!, forKey: assetIdPrefix + asset.localIdentifier)
    }
    
    //
    // Check if file has already been uploaded, based on the hash.
    //
    let uploaded = try await checkFileUploaded(hash: fileDetails.hash!)
    if (uploaded) {
      // Record that this file has already been uploaded.
      fileDetails.uploaded = true

      // Update record in local storage.
      let jsonData = try JSONEncoder().encode(fileDetails)
      uploadList.set(String(data: jsonData, encoding: .utf8)!, forKey: assetIdPrefix + asset.localIdentifier)
      return
    }
        
    if fileDetails.location == nil && asset.location != nil {
      // Reverse geocode the location.
      fileDetails.location = try await reverseGeocode(location: asset.location!)
      if fileDetails.location != nil {
        // Update record in local storage.
        let jsonData = try JSONEncoder().encode(fileDetails)
        uploadList.set(String(data: jsonData, encoding: .utf8)!, forKey: assetIdPrefix + asset.localIdentifier)
      }
    }
    
    //
    // Test to get EXIF data.
    //
    let properties = try await getAssetProperties(asset)
    print("Got properties:")
    print(properties)
    
    //
    // Now actually upload the file.
    //
    try await uploadFile(contentType, fileDetails, assetData)
    
    //
    // Record that the file was uploaded.
    //
    fileDetails.uploaded = true
    
    let jsonData = try JSONEncoder().encode(fileDetails)
    uploadList.set(String(data: jsonData, encoding: .utf8)!, forKey: assetIdPrefix + asset.localIdentifier)
  }
  
  private let assetIdPrefix = "xid_";
  
  //
  // Internal and async method to scan for media and upload.
  //
  private func _scanMedia() async throws -> Void {
    try await requestPermission()
    
    let uploadList = UserDefaults(suiteName: "local-media")!

    //
    // Remove previous settings.
    //
    // https://stackoverflow.com/a/43402172
    //
    for key in uploadList.dictionaryRepresentation().keys {
      if key.starts(with: assetIdPrefix) {
        print("Removing " + key)
        uploadList.removeObject(forKey: key)
      }
    }

    let options = PHFetchOptions()
    //todo: http://www.gfrigerio.com/read-exif-data-of-pictures/
//    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    let result = PHAsset.fetchAssets(with: options)
    var items: [PHAsset] = []
    result.enumerateObjects { asset, _, _ in
      items.append(asset)
    }
    
    print("********** Saving upload list ************")

    // https://stackoverflow.com/a/33186219
    let jsonEncoder = JSONEncoder();

    for asset in items {
      let existingAssetJson = uploadList.string(forKey: assetIdPrefix + asset.localIdentifier)
      if (existingAssetJson == nil) {
        // No record yet for this asset.
        let resource = PHAssetResource.assetResources(for: asset)[0]
        let mimetype = UTType(resource.uniformTypeIdentifier)!.preferredMIMEType!
                
        let fileDetails = FileDetails(
          name: resource.originalFilename,
          localAssetid: asset.localIdentifier,
          contentType: mimetype,
          hash: nil,
          uploaded: false,
          width: resource.pixelWidth,
          height: resource.pixelHeight
        )
        let jsonData = try jsonEncoder.encode(fileDetails)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        uploadList.set(jsonString, forKey: assetIdPrefix + asset.localIdentifier)
      }
      else {
        print("Already have record for " + asset.localIdentifier)
      }
    }
    
    //
    // Print all upload records in storage.
    //
//    for (key, value) in uploadList.dictionaryRepresentation() {
//      if key.starts(with: assetIdPrefix) {
//        print("\(key) = \(value) \n")
//      }
//    }

    print("********** Uploading assets ************")
    
    for asset in items {
      try await uploadAsset(assetLocalId: asset.localIdentifier, uploadList: uploadList)
    }
    
    print("========== Done ===========")
  }
  
  //
  // Starts scanning and uploading of media.
  //
  public func scanMedia() {
    Task {
      do {
        try await _scanMedia();
      }
      catch {
        print("scanMedia failed with error: \(error)")
      }
    }
  }
}
