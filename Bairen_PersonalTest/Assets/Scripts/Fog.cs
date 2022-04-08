using UnityEngine;
[ExecuteInEditMode]
public class Fog : MonoBehaviour
{
    public bool enable;
    public Color fogColor;
    public Color scatterLight;
    public float heightBias;
    [Min(0f)]public float heightFallOff;
    public float distFalloff;
    public float distBias;
    public float scatterPow;

    private static readonly int FogColor = Shader.PropertyToID("_FogCol");
    private static readonly int HeightFallOff = Shader.PropertyToID("_HeightFalloff");
    private static readonly int HeightBias = Shader.PropertyToID("_HeightBias");
    
    private static readonly int DistFalloff = Shader.PropertyToID("_DistFalloff");
    
    private static readonly int DistBias = Shader.PropertyToID("_DistBias");
    private static readonly int ScatterPow = Shader.PropertyToID("_ScatterPow");
    private static readonly int ScatterLight = Shader.PropertyToID("_ScatterLight");

    void OnValidate()
    {
        Shader.SetGlobalColor(FogColor, fogColor);
        Shader.SetGlobalFloat(HeightFallOff, heightFallOff);
        Shader.SetGlobalFloat(HeightBias, heightBias);
        Shader.SetGlobalFloat(DistFalloff, distFalloff);
        Shader.SetGlobalFloat(DistBias, distBias);
        Shader.SetGlobalFloat(ScatterPow, scatterPow);
        Shader.SetGlobalColor(ScatterLight, scatterLight);
        if (enable)
        {
            Shader.EnableKeyword("_FOG_ON");
        }
        else
        {
            Shader.DisableKeyword("_FOG_ON");
        }
    }
}
