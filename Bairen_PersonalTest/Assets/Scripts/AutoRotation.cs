using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AutoRotation : MonoBehaviour
{
    [Range(0.25f, 4.0f)] 
    public float RotationSpeed = 1.0f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.Rotate(Vector3.left,Time.deltaTime * 10 * RotationSpeed,Space.Self);
    }
}
