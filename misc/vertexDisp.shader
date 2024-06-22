Shader "Vertex Displacement" {
   //simple random vertex displacement influenced by the intensity of a noise texture
    Properties{
       _MainTex("Main Texture", 2D) = "white" {}
       _DisplacementTex("Displacement Texture", 2D) = "white" {}
       //_MaxDisplacement("Max Displacement", Float) = 1.0
       _MaxDisplacement("Max Displacement", Range(0,.1)) = 1
    }

        CGINCLUDE


       float random(float seed)
       {
           return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
       }

        ENDCG



        SubShader{
           Pass {
              CGPROGRAM

              #pragma vertex vert
              #pragma fragment frag

              uniform sampler2D _MainTex;
              uniform sampler2D _DisplacementTex;
              uniform float _MaxDisplacement;

              struct appdata {
                 float4 vertex : POSITION;
                 float3 normal : NORMAL;
                 float4 texcoord : TEXCOORD0;
              };

              struct v2f {
                 float4 position : SV_POSITION;
                 float4 texcoord : TEXCOORD0;
              };

              v2f vert(appdata i) {
                 v2f o;

                 // get color from displacement map, and convert to float from 0 to _MaxDisplacement
                 float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(i.texcoord.xy, 0.0, 0.0));
                 float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb) * _MaxDisplacement;

                 // displace vertices along surface normal vector
                 //float4 newVertexPos = i.vertex + float4(i.normal * displacement, 0.0);
                 //float4 newVertexPos = i.vertex + float4(random(i.normal.x) * displacement, 0.0);
                 float4 newVertexPos = i.vertex + float4(random(i.vertex.x) * displacement, random(i.normal.y) * displacement, random(i.texcoord.z) * displacement, 0.0);

                 // output data            
                 o.position = UnityObjectToClipPos(newVertexPos);
                 o.texcoord = i.texcoord;
                 return o;

              }

              float4 frag(v2f i) : COLOR
              {
                 return tex2D(_MainTex, i.texcoord.xy);
              }

              ENDCG
           }
       }
}