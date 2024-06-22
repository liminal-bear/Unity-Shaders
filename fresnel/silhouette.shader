Shader "Silhouette" {

    //this shader adds a silhoutte on the model
    //the color changes to _SilhouetteColor the more sideways the view direction is from the face normal
    //adapted from this link
    //https://en.wikibooks.org/wiki/Cg_Programming/Unity/Silhouette_Enhancement
    //changed to not use alpha blend, but instead to be a color change
    //this effect is used in Hologram

    Properties{
       _Color("Color", Color) = (1, 1, 1, 0.5)
       _SilhouetteColor("Silhouette Color", Color) = (0, 0, 0, 1)
       _RimSize("Rim Size", Range(0, 4)) = 0.6
       _Gradient("Gradient", Range(0, 4)) = 0.6
       // user-specified RGBA color including opacity
    }
        SubShader{
           Tags { "Queue" = "Transparent" }
           // draw after all opaque geometry has been drawn
        Pass {
           ZWrite On
           Cull Off
           //Blend SrcAlpha OneMinusSrcAlpha // standard alpha blending

           CGPROGRAM

           #pragma vertex vert  
           #pragma fragment frag 

           #include "UnityCG.cginc"

           uniform float4 _Color; // define shader property for shaders
           uniform float4 _SilhouetteColor; // define shader property for shaders
           half _RimSize;
           half _Gradient;

           struct appdata {
              float4 vertex : POSITION;
              float3 normal : NORMAL;
           };
           struct v2f {
              float4 pos : SV_POSITION;
              float3 normal : TEXCOORD0;
              float3 viewDir : TEXCOORD1;
           };

           v2f vert(appdata input)
           {
              v2f output;

              float4x4 modelMatrix = unity_ObjectToWorld;
              float4x4 modelMatrixInverse = unity_WorldToObject;

              output.normal = normalize(
                 mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
              output.viewDir = normalize(_WorldSpaceCameraPos
                 - mul(modelMatrix, input.vertex).xyz);

              output.pos = UnityObjectToClipPos(input.vertex);
              return output;
           }

           float4 frag(v2f input) : COLOR
           {
              float3 normalDirection = normalize(input.normal);
              float3 viewDirection = normalize(input.viewDir);

              float silhouette = min(1.0, .25 / abs(pow(dot(viewDirection, normalDirection) * _Gradient, _RimSize)));

              float3 col = lerp(_Color.rgb, _SilhouetteColor.rgb, silhouette);

              return float4(col.rgb, 1);
           }

           ENDCG
        }
    }
}