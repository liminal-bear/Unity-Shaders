Shader "Cg shader with refraction mapping" {
    Properties{
       _Cube("Reflection Map", Cube) = "" {}
       _Tint("Tint Color", Color) = (0,156,134)
       _RimSize("Rim Size", Range(0, 100)) = 0.6
       _RimBrightness("Rim Brightness", Range(0, 10)) = 10
    }
        SubShader{
           Tags { "Queue" = "Transparent" }
           Pass {
              //ZWrite On // don't occlude other objects
              Blend SrcAlpha OneMinusSrcAlpha // standard alpha blending
              Cull Off
              CGPROGRAM

              #pragma vertex vert  
              #pragma fragment frag 

              #include "UnityCG.cginc"

              // User-specified uniforms
              uniform samplerCUBE _Cube;
              fixed4 _Tint;
              half _RimSize, _RimBrightness;

              struct vertexInput {
                 float4 vertex : POSITION;
                 float3 normal : NORMAL;
              };
              struct vertexOutput {
                 float4 pos : SV_POSITION;
                 float3 normal : TEXCOORD0;
                 float3 viewDir : TEXCOORD1;
              };

              vertexOutput vert(vertexInput input)
              {
                 vertexOutput output;

                 float4x4 modelMatrix = unity_ObjectToWorld;
                 float4x4 modelMatrixInverse = unity_WorldToObject;

                 output.viewDir = mul(modelMatrix, input.vertex).xyz
                    - _WorldSpaceCameraPos;
                 //output.viewDir = normalize(_WorldSpaceCameraPos
                 //    - mul(modelMatrix, input.vertex).xyz);
                 output.normal = normalize(
                    mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
                 output.pos = UnityObjectToClipPos(input.vertex);
                 return output;
              }

              float4 frag(vertexOutput input) : COLOR
              {
                 float refractiveIndex = 1.5;
                 float3 refractedDir = refract(normalize(input.viewDir),
                    normalize(input.normal), 1.0 / refractiveIndex);

                 float3 normalDir = normalize(input.normal);
                 float3 viewDir = -normalize(input.viewDir);
                 float newOpacity = min(1.0, _Tint.a
                     / abs(pow(dot(viewDir, normalDir), _RimSize)));
                 newOpacity = newOpacity > 0.5 ? 1 : 0;
                 //newOpacity = Quantize(newOpacity, 10);



                 float4 col = texCUBE(_Cube, refractedDir);
                 //col += 0.1 * _RimBrightness * float4(_Tint.rgb * (newOpacity), 0);
                 col.a = 1 - newOpacity;



                 return col;
              }

              ENDCG
           }
    }
}