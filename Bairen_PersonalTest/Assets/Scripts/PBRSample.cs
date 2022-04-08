using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class PBRSample : MonoBehaviour
{
    public Shader pbrShader;

    void Start()
    {
        if (pbrShader != null)
        {
            Vector3 pos0 = transform.GetChild(0).GetComponent<Transform>().position;
            for (int it = 0; it < transform.childCount; it++)
            {
                Material tempMat = new Material(pbrShader);
                var rend = transform.GetChild(it).GetComponent<Renderer>();
                Vector3 pos = transform.GetChild(it).GetComponent<Transform>().position;
                tempMat.SetFloat("_Metallic", (pos.y - pos0.y) / 7.5f);
                tempMat.SetFloat("_Smoothness", (pos.x - pos0.x) / 7.5f);
                rend.material = tempMat;
            }
        }

        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
