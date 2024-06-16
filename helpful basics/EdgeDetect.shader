Shader "EdgeDetect"
{
    Properties
    {
        _MainTex ("Depth Texture", 2D) = "white" {}
        _Color ("Wireframe Color", Color) = (1,1,1,1)
        _Thickness ("Wireframe Thickness", Range(0.001, 0.1)) = 0.01
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
    }
    SubShader
    {
        Tags { "Queue" = "Overlay" }
        Pass
        {
            Cull[_Cull]
			ZWrite[_ZWrite]
			Ztest[_ZTest]
            ColorMask RGB
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            uniform sampler2D _MainTex;
            uniform float4 _Color;
            uniform float _Thickness;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half depth = tex2D(_MainTex, i.uv).r;
                half ddx_depth = ddx(depth);
                half ddy_depth = ddy(depth);
                half2 gradient = half2(ddx_depth, ddy_depth);

                half thickness = _Thickness * _ProjectionParams.y / depth;
                half2 offset = thickness * normalize(gradient);

                half4 color = _Color;

                if (depth == 1)
                    discard;

                // Draw wireframe
                half4 wireColor = half4(0,0,0,1); // Black
                half wireDepth = 0.5;
                if (abs(depth - wireDepth) < thickness || abs(depth - tex2D(_MainTex, i.uv + offset).r) < thickness || abs(depth - tex2D(_MainTex, i.uv - offset).r) < thickness || abs(depth - tex2D(_MainTex, i.uv + offset.yx).r) < thickness || abs(depth - tex2D(_MainTex, i.uv - offset.yx).r) < thickness)
                    color = wireColor;

                return color;
            }
            ENDCG
        }
    }
}
