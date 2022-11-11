Shader "Hidden/paramater viewer"
{

    //This shader is designed to give some insight on the input parameters a shader can get, as well as some derived values
    //to get a better idea of how to utilize these derived values, you can take a look at matcap, LitBase, or Scootoon_2

    Properties
    {
        [Toggle] _Category("Raw parameters or derived values?", Int) = 0
        //raw input parameters
        //[Enum(pos, 0, posWorld, 1, posScreen, 2, tex, 3, tangentWorld, 4, normalWorld, 5, binormalWorld, 6, vlight, 7)] _Parameter("Parameter to view", Int) = 0
        [Enum(pos, 0, posWorld, 1, posScreen, 2, tex, 3, tangentWorld, 4, normalWorld, 5, binormalWorld, 6)] _Parameter("Parameter to view", Int) = 0
        //some derived values
        [Enum(viewDirection, 0, headDirection, 1, normalViewDirection, 2, bitangentViewDirection,3, tangentViewDirection, 4)] _Derived("Derived values", Int) = 0
    }

    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"

        uniform int _Category;
        uniform int _Parameter;
        uniform int _Derived;

        float3 blendVRParallax(float3 a, float3 b, float c)
        {
#if defined(USING_STEREO_MATRICES)
            return lerp(a, b, c);
#else
            return b;
#endif
        }

        float3 orthoNormalize(float3 tangent, float3 normal)
        {
            return normalize(tangent - normal * dot(normal, tangent));
        }

        ENDCG

        Pass
        {
            CGPROGRAM

            #pragma vertex vert  
            #pragma fragment frag

            struct vertexInput
            {
                    float4 vertex : POSITION;
                    float4 texcoord : TEXCOORD0;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float4 posWorld : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                // position of the vertex (and fragment) in world space 
                float4 tex : TEXCOORD2;
                float3 tangentWorld : TEXCOORD3;
                float3 normalWorld : TEXCOORD4;
                float3 binormalWorld : TEXCOORD5;
                //fixed3 vLight : COLOR;
                //LIGHTING_COORDS(5, 6)
                    //UNITY_LIGHTING_COORDS(6, 7)
                    //V2F_SHADOW_CASTER
            };

            vertexOutput vert(vertexInput input)
            {
                vertexOutput output;

                float4x4 modelMatrix = unity_ObjectToWorld;
                float4x4 modelMatrixInverse = unity_WorldToObject;

                output.tangentWorld = normalize(
                    mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
                output.normalWorld = normalize(
                    mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
                output.binormalWorld = normalize(
                    cross(output.normalWorld, output.tangentWorld)
                    * input.tangent.w); // tangent.w is specific to Unity

                output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
                output.tex = input.texcoord;
                output.pos = UnityObjectToClipPos(input.vertex);
                output.screenPos = ComputeScreenPos(output.pos);

                half3 worldN = UnityObjectToWorldNormal(input.normal);
                half3 shlight = ShadeSH9(float4(worldN, 1.0));
                //output.vLight = shlight;
                return output;

            }

            float4 frag(vertexOutput input) : COLOR
            {
                if (_Category == 0)
                {
                    switch (_Parameter)
                    {
                        case 0:
                            return input.pos;
                            break;
                        case 1:
                            return input.posWorld;
                            break;
                        case 2:
                            return input.screenPos;
                            break;
                        case 3:
                            return input.tex;
                            break;
                        case 4:
                            return float4(input.tangentWorld, 1);
                            break;
                        case 5:
                            return float4(input.normalWorld,1);
                            break;
                        case 6:
                            return float4(input.binormalWorld,1);
                            break;
                    }
                    return float4(0, 0, 0, 1);
                }
                else
                {
                    float3 headDirection;

#if defined(USING_STEREO_MATRICES)
//float x = _XRWorldSpaceCameraPos[i](0).xyz
                    headDirection = normalize(unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz + unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz * 0.5) - input.posWorld;
#else
                    headDirection = normalize(UNITY_MATRIX_V._m20_m21_m22);
#endif
                    float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

                    float3 normalViewDirection = blendVRParallax(headDirection, viewDirection, 0.5);
                    //float3 bitangentViewDirection = UNITY_MATRIX_V._m10_m11_m12;
                    float3 bitangentViewDirection = float3(0, 1, 0);
                    bitangentViewDirection = orthoNormalize(bitangentViewDirection, normalViewDirection);

                    float3 tangentViewDirection = cross(normalViewDirection, bitangentViewDirection);
                    switch (_Derived)
                    {
                       
                        case 0:
                            return float4(viewDirection, 1);
                            break;
                        case 1:
                            return float4(headDirection, 1);
                            break;
                        case 2:
                            return float4(normalViewDirection, 1);
                            break;
                        case 3:
                            return float4(bitangentViewDirection, 1);
                            break;
                        case 4:
                            return float4(tangentViewDirection, 1);
                    }
                }
                return float4(0,0,0,1);
            }

        ENDCG
        }
    }
}