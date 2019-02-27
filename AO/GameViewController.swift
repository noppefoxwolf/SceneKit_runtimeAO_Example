//
//  GameViewController.swift
//  AO
//
//  Created by Tomoya Hirano on 2019/02/27.
//  Copyright © 2019 Tomoya Hirano. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import SceneKit.ModelIO

class GameViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    
    // create a new scene
    let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    // create and add an ambient light to the scene
    let ambientLightNode = SCNNode()
    ambientLightNode.light = SCNLight()
    ambientLightNode.light!.type = .ambient
    ambientLightNode.light!.color = UIColor.white
    scene.rootNode.addChildNode(ambientLightNode)
    
    let plane = SCNPlane()
    plane.width = 75
    plane.height = 75
    plane.name = "com.noppelab.plane"
    let planeNode = SCNNode()
    let d = -90 * (Float.pi / 180)
    planeNode.eulerAngles = .init(d, 0, 0)
    planeNode.position = .init(0, 0, 0)
    planeNode.geometry = plane
    planeNode.name = "com.noppelab.plane"
    scene.rootNode.addChildNode(planeNode)
    
    // retrieve the SCNView
    let scnView = self.view as! SCNView
    
    // set the scene to the view
    scnView.scene = scene
    
    // allows the user to manipulate the camera
    scnView.allowsCameraControl = true
    
    // show statistics such as fps and timing information
    scnView.showsStatistics = true
    
    // configure the view
    scnView.backgroundColor = UIColor.black
    
    bake(nodeName: "com.noppelab.plane")
  }
  
  func flattenObjectInMeshes(parentTransform: inout simd_float4x4, object: MDLObject, meshArray: inout Array<MDLMesh>) {
    if let transform = object.transform {
      parentTransform = simd_mul(parentTransform, transform.matrix)
    }
    
    if let mesh = object as? MDLMesh {
      mesh.transform = MDLTransform(matrix: parentTransform)
      meshArray.append(mesh)
    } else {
      for o in object.children.objects {
        flattenObjectInMeshes(parentTransform: &parentTransform, object: o, meshArray: &meshArray)
      }
    }
  }
  
  func flattenMeshes(asset: MDLAsset) -> [MDLMesh] {
    var parentTransform = matrix_identity_float4x4
    var meshArray: [MDLMesh] = .init()
    for i in 0..<asset.count {
      flattenObjectInMeshes(parentTransform: &parentTransform, object: asset.object(at: i), meshArray: &meshArray)
    }
    return meshArray
  }
  
  func bake(nodeName: String) {
    guard let scnView = self.view as? SCNView, let scene = scnView.scene else {return}
    let asset = MDLAsset(scnScene: scene)
    let planeMesh = asset.childObjects(of: MDLMesh.self).filter({ $0.name == nodeName }).first as! MDLMesh
    
    let rootMeshes = flattenMeshes(asset: asset)
    
    // generateAmbientOcclusionTexture will block so do it on a background thread
    DispatchQueue.global().async {
      
      planeMesh.generateAmbientOcclusionTexture(withQuality: 0.5, attenuationFactor: 0.2, objectsToConsider: rootMeshes, vertexAttributeNamed: MDLVertexAttributeTextureCoordinate, materialPropertyNamed: "ambientOcclusion")
      
      DispatchQueue.main.async {
        let planeNode = scene.rootNode.childNode(withName: nodeName, recursively: true)!
        planeNode.geometry = SCNGeometry(mdlMesh: planeMesh)
      }
    }
  }
}
