Shader "RGBTriplePass" {
    Properties{
       _MainTex("Main Texture", 2D) = "white" {}
       _MaxDisplacement("Max Displacement", Float) = 1.0
       _Speed("speed", Float) = 1.0
    }
        SubShader{
           Pass 
           {
                Tags {
                       "LightMode" = "ForwardBase"
       "RenderType" = "Transparent"}
                           ZWrite Off
                Cull Off
                Blend SrcAlpha One
              CGPROGRAM

              #pragma vertex vert
              #pragma fragment frag

              uniform sampler2D _MainTex;
              float _Speed;
              uniform sampler2D _DisplacementTex;
              uniform float _MaxDisplacement;

              struct appdata {
                 float4 vertex : POSITION;
                 float3 normal : NORMAL;
                 float4 tangent : TANGENT;
                 float4 texcoord : TEXCOORD0;
              };

              struct v2f {
                  float4 position : SV_POSITION;
                  float4 posWorld : TEXCOORD0;
                  // position of the vertex (and fragment) in world space 
                  float4 texcoord : TEXCOORD1;
                  float3 tangentWorld : TEXCOORD2;
                  float3 normalWorld : TEXCOORD3;
                  float3 binormalWorld : TEXCOORD4;
                  fixed3 vLight : COLOR;
              };

              v2f vert(appdata i) {
                 v2f o;
                 
                 // get color from displacement map, and convert to float from 0 to _MaxDisplacement
                 float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(i.texcoord.xy, 0.0, 0.0));
                 float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb);

                 //float mySinTime = sin(_Time * _Speed);

                 //int interval = 1 * (mySinTime > 0.3 ? 1 : 0) + -1 * (mySinTime < -0.3 ? 1 : 0);
                 float3 dir = float3(-1,0,0);
                 // displace vertices along surface normal vector
                 float4x4 modelMatrix = unity_ObjectToWorld;
                 o.posWorld = mul(modelMatrix, i.vertex);
                 float3 viewDirection = normalize(
                     _WorldSpaceCameraPos - o.posWorld.xyz);
                 float4 newVertexPos = i.vertex + float4(dir * _MaxDisplacement * viewDirection.x, 0.0);
                 //float4 newVertexPos = i.vertex * displacement;

                 // output data            
                 o.position = UnityObjectToClipPos(newVertexPos);
                 o.texcoord = i.texcoord;
                 return o;

              }

              float4 frag(v2f i) : COLOR
              {
                 //return tex2D(_MainTex, i.texcoord.xy);
                 return float4(1,0,0,.5);
              }

              ENDCG
           }
           Pass 
           {
                                  Tags {
                       "LightMode" = "ForwardBase"
       "RenderType" = "Transparent"}
                           ZWrite Off
                Cull Off
               Blend SrcAlpha One
                  CGPROGRAM

              #pragma vertex vert
              #pragma fragment frag

              uniform sampler2D _MainTex;
              float _Speed;
              uniform sampler2D _DisplacementTex;
              uniform float _MaxDisplacement;

              struct appdata {
                 float4 vertex : POSITION;
                 float3 normal : NORMAL;
                 float4 tangent : TANGENT;
                 float4 texcoord : TEXCOORD0;
              };

              struct v2f {
                  float4 position : SV_POSITION;
                  float4 posWorld : TEXCOORD0;
                  // position of the vertex (and fragment) in world space 
                  float4 texcoord : TEXCOORD1;
                  float3 tangentWorld : TEXCOORD2;
                  float3 normalWorld : TEXCOORD3;
                  float3 binormalWorld : TEXCOORD4;
                  fixed3 vLight : COLOR;
              };

              v2f vert(appdata i) {
                 v2f o;

                 // get color from displacement map, and convert to float from 0 to _MaxDisplacement
                 float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(i.texcoord.xy, 0.0, 0.0));
                 float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb);

                 //float mySinTime = sin(_Time * _Speed);

                 //int interval = 1 * (mySinTime > 0.3 ? 1 : 0) + -1 * (mySinTime < -0.3 ? 1 : 0);
                 float3 dir = float3(0, 0.001, 0.001);
                 // displace vertices along surface normal vector

                 float4x4 modelMatrix = unity_ObjectToWorld;
                 o.posWorld = mul(modelMatrix, i.vertex);
                 float3 viewDirection = normalize(
                     _WorldSpaceCameraPos - o.posWorld.xyz);
                 float4 newVertexPos = i.vertex + float4(dir * _MaxDisplacement * viewDirection.x, 0.0);
                 //float4 newVertexPos = i.vertex * displacement;

                 // output data            
                 o.position = UnityObjectToClipPos(newVertexPos);
                 o.texcoord = i.texcoord;
                 return o;

              }

              float4 frag(v2f i) : COLOR
              {
                  //return tex2D(_MainTex, i.texcoord.xy);
                  return float4(0,1,0,.5);
              }
              ENDCG
           }
           Pass
           {
                                  Tags {
                       "LightMode" = "ForwardBase"
       "RenderType" = "Transparent"}
                           ZWrite Off
                Cull Off
                Blend SrcAlpha One
              
                     CGPROGRAM

                 #pragma vertex vert
                 #pragma fragment frag

                 uniform sampler2D _MainTex;
                 float _Speed;
                 uniform sampler2D _DisplacementTex;
                 uniform float _MaxDisplacement;

                 struct appdata {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
                    float4 texcoord : TEXCOORD0;
                 };

                 struct v2f {
                     float4 position : SV_POSITION;
                     float4 posWorld : TEXCOORD0;
                     // position of the vertex (and fragment) in world space 
                     float4 texcoord : TEXCOORD1;
                     float3 tangentWorld : TEXCOORD2;
                     float3 normalWorld : TEXCOORD3;
                     float3 binormalWorld : TEXCOORD4;
                     fixed3 vLight : COLOR;
                 };

                 v2f vert(appdata i) {
                    v2f o;

                    // get color from displacement map, and convert to float from 0 to _MaxDisplacement
                    float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(i.texcoord.xy, 0.0, 0.0));
                    float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb);

                    //float mySinTime = sin(_Time * _Speed);

                    //int interval = 1 * (mySinTime > 0.3 ? 1 : 0) + -1 * (mySinTime < -0.3 ? 1 : 0);
                    float3 dir = float3(1, 0.002, 0.002);
                    // displace vertices along surface normal vector

                    float4x4 modelMatrix = unity_ObjectToWorld;
                    o.posWorld = mul(modelMatrix, i.vertex);
                    float3 viewDirection = normalize(
                        _WorldSpaceCameraPos - o.posWorld.xyz);
                    float4 newVertexPos = i.vertex + float4(dir * _MaxDisplacement * viewDirection, 0.0);
                    //float4 newVertexPos = i.vertex * displacement;

                    // output data            
                    o.position = UnityObjectToClipPos(newVertexPos);
                    o.texcoord = i.texcoord;
                    return o;

                 }

                 float4 frag(v2f i) : COLOR
                 {
                     //return tex2D(_MainTex, i.texcoord.xy);
                     return float4(0,0,1,.5);
                 }
                 ENDCG
              }
        }
}