Shader "Outline" 
{
    //this shader just gives an outline to a flat colored model
    //to see this in further detail, you can look at Scooton_2

    //the outline effect is achieved with 2 passes, one pass for the base color, and another pass with the outline color, and the vertexes displaced outwards (along normals)

    Properties
    {

        _Color("Color", Color) = (1, 1, 1, 1)

        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", Range(0, 0.1)) = 0.03

    }
    CGINCLUDE
    #include "UnityCG.cginc"
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
        float4 color : COLOR;
    };
    ENDCG
    Subshader
    {
            
   

        Pass
        {

            //Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //#pragma multi_compile_fwdbase
            //#pragma target 3.0
            vertexOutput vert(vertexInput input)
            {
                vertexOutput output;
                output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
                //output.tex = input.texcoord;
                output.pos = UnityObjectToClipPos(input.vertex);
                return output;
            }
            float4 frag(vertexOutput input) : COLOR
            {
                    float4 col = float4(1,1,1,1);

                    return col;
            }
            ENDCG
        }


        Pass
        {

            Cull Front

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            half _OutlineWidth;
            half4 _OutlineColor;


            float4 vert(float4 position : POSITION, float3 normal : NORMAL) : SV_POSITION 
            {
                position.xyz += normal * _OutlineWidth;//offset vertex positions outwards by _OutlineWidth
                return UnityObjectToClipPos(position);
            }


            half4 frag() : SV_TARGET {
                return _OutlineColor;
            }

            ENDCG

        }

    }

}
