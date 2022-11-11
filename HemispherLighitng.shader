// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Cg per-vertex hemisphere lighting" {
    Properties{
       _MainTex("Main Texture", 2D) = "black" {}
       //_Color("Diffuse Material Color", Color) = (1,1,1,1)
       _UpperHemisphereColor("Upper Hemisphere Color", Color)
          = (1,1,1,1)
       _LowerHemisphereColor("Lower Hemisphere Color", Color)
          = (1,1,1,1)
       _UpVector("Up Vector", Vector) = (0,1,0,0)
    }
        SubShader{
           Pass {
              CGPROGRAM

              #pragma vertex vert  
              #pragma fragment frag 

              #include "UnityCG.cginc"

              // shader properties specified by users
              uniform float4 _Color;
              uniform float4 _UpperHemisphereColor;
              uniform float4 _LowerHemisphereColor;
              uniform float4 _UpVector;
              sampler2D _MainTex;

              struct vertexInput {
                 float4 vertex : POSITION;
                 float4 texcoord: TEXCOORD0;
                 float3 normal : NORMAL;
              };
              struct vertexOutput {
                 float4 pos : SV_POSITION;
                 float4 tex : TEXCOORD1;
                 float4 col : COLOR;
                 // the hemisphere lighting computed in the vertex shader
           };

           vertexOutput vert(vertexInput input)
           {
              vertexOutput output;

              float4x4 modelMatrix = unity_ObjectToWorld;
              float4x4 modelMatrixInverse = unity_WorldToObject;

              float3 normalDirection = normalize(
                 mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
              float3 upDirection = normalize(_UpVector);

              float w = 0.5 * (1.0 + dot(upDirection, normalDirection));
              output.col = (w * _UpperHemisphereColor
                  + (1.0 - w) * _LowerHemisphereColor);

              output.pos = UnityObjectToClipPos(input.vertex);
              output.tex = input.texcoord;
              return output;
           }

           float4 frag(vertexOutput input) : COLOR
           {
              float4 color = tex2D(_MainTex, input.tex);
              return color * input.col;
              //return input.col;
           }

           ENDCG
        }
    }
}