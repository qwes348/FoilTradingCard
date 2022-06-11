Shader "Hwang/FoilCardShader"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        [HDR]_FoilColor("Foil color", Color) = (1,1,1,1)
        [HDR]_ShineColor("Shine Color", color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _RandomDirections ("RandomDirections", 2D) = "white" {}
        _Noise ("Noise", 2D) = "white" {}
        _ViewDirectionDisplacement ("view Direction Displacement", float) = 1
        _FoilMask ("foil mask", 2D) = "white" {}
        _MaskThreshold ("MaskThreshold", Range(0, 1)) = 0
        _GradientMap("GradientMap", 2D) = "white" {}
        _ParallaxOffset ("Parallx offset", float) = 0
        _BumpTex("Normal Texture", 2D) = "bump" {}
        _Strength ("Strength", Range(0, 10)) = 1.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        ZWrite off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewDir : TEXCOORD1;
                float3 viewDirTangent : TEXCOORD2;
                float3 normal : NORMAL;
                
                float3 T : TEXCOORD3;
                float3 B : TEXCOORD4;
            };

            fixed4 _Color;
            fixed4 _FoilColor;
            fixed4 _ShineColor;
            sampler2D _MainTex;
            float4 _MainTex_ST;            
            sampler2D _FoilMask;
            sampler2D _Noise;            
            float _ViewDirectionDisplacement;
            sampler2D _RandomDirections;
            sampler2D _GradientMap;
            float _ParallaxOffset;
            float _MaskThreshold; 
            sampler2D _BumpTex;
            float4 _BumpTex_ST;          
            float _Strength;

            half3 Fuc_TangentNormal2WorldNormal(half3 fTangnetNormal, half3 T, half3  B, half3 N)
			{
				float3x3 TBN = float3x3(T, B, N);
				TBN = transpose(TBN);
				return mul(TBN, fTangnetNormal);
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);

                float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
                float3 viewDir = v.vertex.xyz - objCam.xyz;
                float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;
                o.viewDirTangent = float3(
                    dot(viewDir, v.tangent.xyz),
                    dot(viewDir, bitangent.xyz),
                    dot(viewDir, v.normal.xyz)
                );

                o.T = normalize(UnityObjectToWorldDir(v.tangent.xyz));
                o.B = bitangent;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;

                float noise = tex2D(_Noise, i.uv).x;
                float2 uv = i.uv + i.viewDirTangent * noise * _ParallaxOffset;
                float displ = (tex2D(_Noise, uv) * 2.0 - 1.0) * _ViewDirectionDisplacement;
                float3 randomDirs = normalize(tex2D(_RandomDirections, uv).xyz);
                float dotProduct = saturate(dot(i.normal + randomDirs, normalize(i.viewDir + displ)));
                float fresnel = pow(1.0 - dotProduct, 2.0);
                float samplingVal = (sin((i.viewDir.x + i.viewDir.y) * 1.0 * UNITY_TWO_PI) * 0.5 + 0.5) * fresnel;
                float mask = tex2D(_FoilMask, uv).x;

                // fixed4 sheen = step(0.9, sin((i.uv.x + i.uv.y + i.viewDirTangent.x + i.viewDirTangent.y) * UNITY_PI * 0.1) * 0.5 + 0.5);
                fixed4 sheen = step(0.5, sin((i.viewDirTangent.x + i.viewDirTangent.y) * UNITY_PI * 0.1) * 0.5 + 0.5);
                // sheen = tex2D(_GradientMap, i.uv) * sheen * _ShineColor;
                sheen *= tex2D(_GradientMap, i.uv) * _ShineColor * 0.5;
                
                half3 fTangnetNormal = UnpackNormal(tex2D(_BumpTex, i.uv * _BumpTex_ST.rg));
				fTangnetNormal.xy *= _Strength; // 노말강도 조절
				float3 worldNormal = Fuc_TangentNormal2WorldNormal(fTangnetNormal, i.T, i.B, i.normal);

                fixed fNDotL = dot(i.viewDir, worldNormal * 2);

                return lerp(col, tex2D(_GradientMap, uv) * _FoilColor, step(_MaskThreshold, mask)) + sheen * 0.3f * fNDotL;
            }
            ENDCG
        }
    }
}
