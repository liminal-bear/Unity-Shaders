Shader "NormalFlats"
{
    Properties
    {
        _DepthTex("Depth Texture", 2D) = "white" {}
        _CameraParams("Camera Parameters", Vector) = (1, 1, 1, 1)
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float4 vertex : TEXCOORD1;
            };

            float4 _CameraParams;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.vertex = v.vertex;
                return o;
            }

            sampler2D _DepthTex;

            float LinearizeDepth(float depth)
            {
                return _CameraParams.z / (depth * _CameraParams.w - _CameraParams.y);
            }

            float4 frag(v2f i) : SV_TARGET
            {
                float depth = tex2D(_DepthTex, i.pos.xy / i.pos.w).r;
                float d = LinearizeDepth(depth);
                float3 worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;
                float3 dx = ddx(worldPos);
                float3 dy = ddy(worldPos);
                float3 normal = normalize(cross(dx, dy));
                return float4(normal * 0.5 + 0.5, 1.0); // Convert normal to [0,1] range
            }
            ENDCG
        }
    }
}
