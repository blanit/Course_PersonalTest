using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

public class Bloom : MonoBehaviour
{
    //public Material bloomMaterial;
    public Shader bloomShader;

    [Range(0, 4)] 
    public int iterations = 3;                  // 高斯核迭代次数
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;             // 模糊范围
    [Range(1, 3)]
    public int downSample = 2;                  // 屏幕纹理采样尺寸
    [Range(0.0f, 4.0f)]
    public float luminanceThreshold = 1.0f;     // Bloom生效阈值
    [Range(0.0f, 10.0f)]
    public float bloomIntensity = 1.0f;         // Bloom强度

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (bloomShader != null)
        {
            Material material = new Material(bloomShader);//bloomMaterial;
            material.SetFloat("_LuminanceThreshold", luminanceThreshold);
            material.SetFloat("_Intensity", bloomIntensity);
            int rtW = src.width / downSample;
            int rtH = src.height / downSample;

            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;
            
            Graphics.Blit(src, buffer0, material, 0);               // pass0提取图像中较亮的部分

            for (int i = 0; i <= iterations; i++)
            {
                material.SetFloat("_BlurSize", 1.0f + i * blurSpread);
                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                
                Graphics.Blit(buffer0, buffer1, material, 1);       // pass1进行一个方向的一维高斯模糊
                
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                
                Graphics.Blit(buffer0, buffer1, material, 2);       // pass2进行另一方向的一维高斯模糊
                
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }
            
            material.SetTexture("_Bloom", buffer0);
            Graphics.Blit(src, dest, material, 3);                  // 混合原图和模糊后的图
            
            RenderTexture.ReleaseTemporary(buffer0);                    // 此处buffer1和buffer0引用一致，可以统一释放
        }
        else
        {
            Graphics.Blit(src, dest);
        }
        
    }
}
