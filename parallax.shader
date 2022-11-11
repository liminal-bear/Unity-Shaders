Shader "Cg parallax mapping" 
{
    Properties
    {
      _MainTex("Main Texture", 2D) = "white" {}
       _ParallaxMap("Heightmap (in A)", 2D) = "black" {}
       _Parallax("Max Height", Float) = 0.01
       _MaxTexCoordOffset("Max Texture Coordinate Offset", Float) =
          0.01
    }
    CGINCLUDE // common code for all passes of all subshaders
    #include "UnityCG.cginc"
    uniform float4 _LightColor0;
       // color of light source (from "Lighting.cginc")

    // User-specified properties
       sampler2D _MainTex;
    uniform float4 _MainTex_ST;
    uniform sampler2D _ParallaxMap;
    uniform float4 _ParallaxMap_ST;
    uniform float _Parallax;
    uniform float _MaxTexCoordOffset;
    uniform float4 _Color;
    uniform float4 _SpecColor;
    uniform float _Shininess;

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
        // position of the vertex (and fragment) in world space 
        float4 tex : TEXCOORD1;
        float3 tangentWorld : TEXCOORD2;
        float3 normalWorld : TEXCOORD3;
        float3 binormalWorld : TEXCOORD4;
        float3 viewDirWorld : TEXCOORD5;
        float3 viewDirInScaledSurfaceCoords : TEXCOORD6;
        float4 screenPos : TEXCOORD7;
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


        float3 binormal = cross(input.normal, input.tangent.xyz)
            * input.tangent.w;
        // appropriately scaled tangent and binormal 
        // to map distances from object space to texture space

        float3 viewDirInObjectCoords = mul(
            modelMatrixInverse, float4(_WorldSpaceCameraPos, 1.0)).xyz
            - input.vertex.xyz;
        float3x3 localSurface2ScaledObjectT =
            float3x3(input.tangent.xyz, binormal, input.normal);
        // vectors are orthogonal
        output.viewDirInScaledSurfaceCoords =
            mul(localSurface2ScaledObjectT, viewDirInObjectCoords);
        // we multiply with the transpose to multiply with 
        // the "inverse" (apart from the scaling)

        output.posWorld = mul(modelMatrix, input.vertex);
        output.viewDirWorld = normalize(
            _WorldSpaceCameraPos - output.posWorld.xyz);
        output.tex = input.texcoord;
        output.pos = UnityObjectToClipPos(input.vertex);
        output.screenPos = ComputeScreenPos(output.pos);
        return output;
    }

       // fragment shader with ambient lighting
    float4 fragWithAmbient(vertexOutput input) : COLOR
    {
        // parallax mapping: compute height and 
        // find offset in texture coordinates 
        // for the intersection of the view ray 
        // with the surface at this height


        float height = _Parallax * (-0.5 + tex2D(_ParallaxMap, _ParallaxMap_ST.xy * input.tex.xy + _ParallaxMap_ST.zw).x);

        float2 texCoordOffsets = clamp(height * input.viewDirInScaledSurfaceCoords.xy / input.viewDirInScaledSurfaceCoords.z, -_MaxTexCoordOffset, +_MaxTexCoordOffset);

        //float4 col = tex2D(_MainTex, (input.tex.xy + texCoordOffsets) * _MainTex_ST.xy + _MainTex_ST.zw);
        float4 col = tex2D(_MainTex, (input.tex + texCoordOffsets) * _MainTex_ST.xy + _MainTex_ST.zw);

        
      return col;
    }

           // fragement shader for pass 2 without ambient lighting 
          
    ENDCG
    SubShader 
    {
        Pass
        {
            Cull Off
            //Tags { "LightMode" = "ForwardBase" }
            // pass for ambient light and first light source

            CGPROGRAM
            #pragma vertex vert  
            #pragma fragment fragWithAmbient

            // the functions are defined in the CGINCLUDE part
            ENDCG
        }
    }
}