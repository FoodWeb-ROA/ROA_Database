SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."identities" ("provider_id", "user_id", "identity_data", "provider", "last_sign_in_at", "created_at", "updated_at", "id") VALUES
	('a96d2a87-d780-4aac-9a9d-5acc35995f3d', 'a96d2a87-d780-4aac-9a9d-5acc35995f3d', '{"sub": "a96d2a87-d780-4aac-9a9d-5acc35995f3d", "email": "sweeney5285@gmail.com", "language": "EN", "full_name": "Andrew Sweeney", "email_verified": true, "phone_verified": false}', 'email', '2025-06-11 01:24:13.615761+00', '2025-06-11 01:24:13.615815+00', '2025-06-11 01:24:13.615815+00', '64543c0d-f8a4-46d6-b643-1165e99a6c46'),
	('d56fed25-3bac-4aa7-8a61-822d8cb1cd3f', 'd56fed25-3bac-4aa7-8a61-822d8cb1cd3f', '{"sub": "d56fed25-3bac-4aa7-8a61-822d8cb1cd3f", "email": "google@android.com", "email_verified": false, "phone_verified": false}', 'email', '2025-07-09 17:35:13.281739+00', '2025-07-09 17:35:13.284348+00', '2025-07-09 17:35:13.284348+00', 'b5f4657d-da70-4542-a12c-a0fd50492b09'),
	('aa45ca26-8aa4-4cc8-aefc-bfccc9095519', 'aa45ca26-8aa4-4cc8-aefc-bfccc9095519', '{"sub": "aa45ca26-8aa4-4cc8-aefc-bfccc9095519", "email": "apple@apple.com", "email_verified": false, "phone_verified": false}', 'email', '2025-07-03 18:36:43.716105+00', '2025-07-03 18:36:43.716176+00', '2025-07-03 18:36:43.716176+00', 'bfb354cb-ab5d-49cd-9935-11b8af81a7c1'),
	('62e1fa1a-5f81-465f-9cbb-418fa95526c3', '62e1fa1a-5f81-465f-9cbb-418fa95526c3', '{"sub": "62e1fa1a-5f81-465f-9cbb-418fa95526c3", "email": "maggie.q.l@hotmail.com", "language": "ES", "full_name": "Marga Lee", "email_verified": true, "phone_verified": false}', 'email', '2025-07-10 16:59:26.821174+00', '2025-07-10 16:59:26.821232+00', '2025-07-10 16:59:26.821232+00', '36d0405b-0c8b-4fa8-af01-402194984146'),
	('105513723957372797962', 'be7996aa-4555-4eb1-9832-9244ad1d66a3', '{"iss": "https://accounts.google.com", "sub": "105513723957372797962", "name": "Vitika Agarwal", "email": "vitika.agarwal@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocL57vIe0T0VwRk5yYM7bcfcUI7IkbVMGmMhbsajnn4kv54mOQ=s96-c", "full_name": "Vitika Agarwal", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocL57vIe0T0VwRk5yYM7bcfcUI7IkbVMGmMhbsajnn4kv54mOQ=s96-c", "provider_id": "105513723957372797962", "email_verified": true, "phone_verified": false}', 'google', '2025-07-11 10:48:47.235557+00', '2025-07-11 10:48:47.235611+00', '2025-07-11 10:48:47.235611+00', 'fd60a396-d88a-483a-8bcf-b29e59d881fe'),
	('f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c', 'f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c', '{"sub": "f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c", "email": "immagprats@hotmail.com", "language": "ES", "full_name": "Imma g prats", "email_verified": true, "phone_verified": false}', 'email', '2025-07-09 15:24:51.634608+00', '2025-07-09 15:24:51.634671+00', '2025-07-09 15:24:51.634671+00', '4c4ad1bd-47dc-4ec9-8309-937901715959'),
	('814076fa-5459-44de-a281-39617339670f', '814076fa-5459-44de-a281-39617339670f', '{"sub": "814076fa-5459-44de-a281-39617339670f", "email": "piazzolla.luca93@gmail.com", "language": "IT", "full_name": "Luca Piazzolla", "email_verified": true, "phone_verified": false}', 'email', '2025-07-11 17:01:50.275853+00', '2025-07-11 17:01:50.275923+00', '2025-07-11 17:01:50.275923+00', 'dd51c6fd-ffcb-49d8-bd8a-16778e99f313'),
	('c9cdd2fd-42f2-4813-b9b1-0fa04996d270', 'c9cdd2fd-42f2-4813-b9b1-0fa04996d270', '{"sub": "c9cdd2fd-42f2-4813-b9b1-0fa04996d270", "email": "fabianisamat@icloud.com", "language": "EN", "full_name": "Fabian Isamat", "email_verified": true, "phone_verified": false}', 'email', '2025-07-12 08:26:23.601321+00', '2025-07-12 08:26:23.601378+00', '2025-07-12 08:26:23.601378+00', 'b272293e-4cb8-49e8-879d-9dd91698ffda'),
	('113988168301739355385', 'dc93a6ed-19b4-4576-8ebf-6b7d0e928ef7', '{"iss": "https://accounts.google.com", "sub": "113988168301739355385", "name": "Ignasi Frechoso", "email": "ifrechoso@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocK1pQWsXW9QTpXi3e0V_Q7733AnEVC3MhbjgUOIWSPS7Tw5OLaGfw=s96-c", "full_name": "Ignasi Frechoso", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocK1pQWsXW9QTpXi3e0V_Q7733AnEVC3MhbjgUOIWSPS7Tw5OLaGfw=s96-c", "provider_id": "113988168301739355385", "email_verified": true, "phone_verified": false}', 'google', '2025-07-13 18:58:51.32825+00', '2025-07-13 18:58:51.328329+00', '2025-07-13 18:58:51.328329+00', 'eed3496f-368b-4f86-a14f-4f3ef8187482'),
	('cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', 'cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', '{"sub": "cba1e62a-bf31-40a0-8387-7fa37e1c4ef1", "email": "mimmoferretti@hotmail.com", "language": "IT", "full_name": "Mimmo", "email_verified": true, "phone_verified": false}', 'email', '2025-07-15 16:10:13.292906+00', '2025-07-15 16:10:13.292975+00', '2025-07-15 16:10:13.292975+00', '652f2812-d3fa-43f0-8d44-0671ce3081c4'),
	('109768390582370592858', '1ed4c627-5891-4805-801a-f521bf146e93', '{"iss": "https://accounts.google.com", "sub": "109768390582370592858", "name": "Yago Ferretti", "email": "yago@foodweb.ai", "picture": "https://lh3.googleusercontent.com/a/ACg8ocK9uLHdqaFQdfaEkjNrGu6BmtF_RmhPlqyzBgn-c0auMWUlxg=s96-c", "full_name": "Yago Ferretti", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocK9uLHdqaFQdfaEkjNrGu6BmtF_RmhPlqyzBgn-c0auMWUlxg=s96-c", "provider_id": "109768390582370592858", "custom_claims": {"hd": "foodweb.ai"}, "email_verified": true, "phone_verified": false}', 'google', '2025-07-11 15:54:58.853704+00', '2025-07-11 15:54:58.853756+00', '2025-08-01 15:11:17.930476+00', 'ef27f7af-321d-4d33-be11-cf1b6cc9dfac'),
	('6de3dcac-68b8-48b3-8fd4-79f3e2ee560b', '6de3dcac-68b8-48b3-8fd4-79f3e2ee560b', '{"sub": "6de3dcac-68b8-48b3-8fd4-79f3e2ee560b", "email": "aa5507@columbia.edu", "full_name": "Arnav", "email_verified": true, "phone_verified": false}', 'email', '2025-07-17 10:26:18.781509+00', '2025-07-17 10:26:18.781581+00', '2025-07-17 10:26:18.781581+00', '44e9b8cc-01ea-4979-894d-f83bbb5fde35'),
	('a0466a40-9577-4d72-ba89-320138b87cf5', 'a0466a40-9577-4d72-ba89-320138b87cf5', '{"sub": "a0466a40-9577-4d72-ba89-320138b87cf5", "email": "mtspana@verizon.net", "language": "EN", "full_name": "james franco", "email_verified": true, "phone_verified": false}', 'email', '2025-05-25 20:51:44.49246+00', '2025-05-25 20:51:44.492511+00', '2025-05-25 20:51:44.492511+00', '8ca0b827-1a6a-4015-9318-dc9b999ba0a9'),
	('bd8f6c9a-a1c5-4f32-b512-d9ce889a5a69', 'bd8f6c9a-a1c5-4f32-b512-d9ce889a5a69', '{"sub": "bd8f6c9a-a1c5-4f32-b512-d9ce889a5a69", "email": "vincent.matont@hotmail.it", "full_name": "Vincenzo Matonti ", "email_verified": true, "phone_verified": false}', 'email', '2025-07-17 21:55:32.931067+00', '2025-07-17 21:55:32.93112+00', '2025-07-17 21:55:32.93112+00', '06b09b07-a609-493a-a650-1f762daf62f6'),
	('f6ee302b-8550-4a16-9d40-484695473337', 'f6ee302b-8550-4a16-9d40-484695473337', '{"sub": "f6ee302b-8550-4a16-9d40-484695473337", "email": "iandurkin14@gmail.com", "full_name": "Ian Durkin", "email_verified": true, "phone_verified": false}', 'email', '2025-07-24 11:04:28.711699+00', '2025-07-24 11:04:28.711755+00', '2025-07-24 11:04:28.711755+00', '38d6a788-6101-4d63-b74a-b7c7d5193e14'),
	('7acd597a-56c3-412b-b821-27e3c668cf2d', '7acd597a-56c3-412b-b821-27e3c668cf2d', '{"sub": "7acd597a-56c3-412b-b821-27e3c668cf2d", "email": "maximepetitpatisserie@gmail.com", "full_name": "Maxime Petit ", "email_verified": true, "phone_verified": false}', 'email', '2025-07-31 13:04:46.810618+00', '2025-07-31 13:04:46.810668+00', '2025-07-31 13:04:46.810668+00', 'd0e50058-8486-4ff6-add3-e9b1ce650d90'),
	('000544.acaff2e84ac64fc99d5a2e70fa1ca8e8.2120', 'ecf29cba-f0d6-4a33-a563-dcbafc920726', '{"iss": "https://appleid.apple.com", "sub": "000544.acaff2e84ac64fc99d5a2e70fa1ca8e8.2120", "email": "6cc4zpwnkv@privaterelay.appleid.com", "provider_id": "000544.acaff2e84ac64fc99d5a2e70fa1ca8e8.2120", "custom_claims": {"auth_time": 1753996855}, "email_verified": true, "phone_verified": false}', 'apple', '2025-07-31 21:20:57.764959+00', '2025-07-31 21:20:57.765014+00', '2025-07-31 21:20:57.765014+00', 'affdb7bf-7238-4fdf-897a-d42e8cf57fdd'),
	('eb32943a-afee-4480-8a9d-c4e724668990', 'eb32943a-afee-4480-8a9d-c4e724668990', '{"sub": "eb32943a-afee-4480-8a9d-c4e724668990", "email": "arnav@foodweb.ai", "language": "EN", "full_name": "Arnav Agarwal", "email_verified": true, "phone_verified": false}', 'email', '2025-04-24 15:08:15.86943+00', '2025-04-24 15:08:15.869481+00', '2025-04-24 15:08:15.869481+00', '6eceec4a-93a1-498d-b09b-662ac0c3aff4'),
	('110872887563161425191', 'eb32943a-afee-4480-8a9d-c4e724668990', '{"iss": "https://accounts.google.com", "sub": "110872887563161425191", "name": "Arnav Agarwal", "email": "arnav@foodweb.ai", "picture": "https://lh3.googleusercontent.com/a/ACg8ocIu5SvYUtHMudDkzLEH-5xFM_f9QYqQzvkIFLgrxeKqHRvyMw=s96-c", "full_name": "Arnav Agarwal", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocIu5SvYUtHMudDkzLEH-5xFM_f9QYqQzvkIFLgrxeKqHRvyMw=s96-c", "provider_id": "110872887563161425191", "custom_claims": {"hd": "foodweb.ai"}, "email_verified": true, "phone_verified": false}', 'google', '2025-07-16 20:04:39.211714+00', '2025-07-16 20:04:39.212361+00', '2025-08-08 17:52:15.920546+00', 'f404a8c3-373d-4c5d-8b3e-68608fee42dd'),
	('3a6970e0-6b0e-4ee0-9ad5-0b4368026f16', '3a6970e0-6b0e-4ee0-9ad5-0b4368026f16', '{"sub": "3a6970e0-6b0e-4ee0-9ad5-0b4368026f16", "email": "chris.maniakis@gmail.com", "full_name": "Christos ", "email_verified": true, "phone_verified": false}', 'email', '2025-08-02 18:37:01.879228+00', '2025-08-02 18:37:01.879292+00', '2025-08-02 18:37:01.879292+00', 'eefda412-e9eb-49a1-91ac-d0f274c921e5'),
	('2cb67821-d674-478e-8c2d-f5ba8392d0f0', '2cb67821-d674-478e-8c2d-f5ba8392d0f0', '{"sub": "2cb67821-d674-478e-8c2d-f5ba8392d0f0", "email": "yagofererri@gmail.com", "full_name": "Yagi", "email_verified": false, "phone_verified": false}', 'email', '2025-08-08 10:37:53.009161+00', '2025-08-08 10:37:53.009217+00', '2025-08-08 10:37:53.009217+00', 'a3a9faa7-2477-4d6a-99a5-75f7389fca7b'),
	('114790095651066959813', '457736da-0fb6-4bc6-a1d8-83acb178997e', '{"iss": "https://accounts.google.com", "sub": "114790095651066959813", "name": "Sebastián Vallejo", "email": "sebastianvallejobetancourt@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocL97OQ6YhL1QK1L41kpQAsgFB1Q02s-LxkuJq0Cg9WiJwV_8Q=s96-c", "full_name": "Sebastián Vallejo", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocL97OQ6YhL1QK1L41kpQAsgFB1Q02s-LxkuJq0Cg9WiJwV_8Q=s96-c", "provider_id": "114790095651066959813", "email_verified": true, "phone_verified": false}', 'google', '2025-08-12 16:25:57.383071+00', '2025-08-12 16:25:57.383124+00', '2025-08-12 16:25:57.383124+00', 'e2d70330-8af7-4aec-ac77-5ee8285f3d51'),
	('a8b860f9-2109-458a-a48d-8369b63f387d', 'a8b860f9-2109-458a-a48d-8369b63f387d', '{"sub": "a8b860f9-2109-458a-a48d-8369b63f387d", "email": "adrian@colmadocarpanta.es", "full_name": "Adrián López", "email_verified": true, "phone_verified": false}', 'email', '2025-08-20 09:04:25.654924+00', '2025-08-20 09:04:25.655001+00', '2025-08-20 09:04:25.655001+00', '2773c958-c9ac-4319-9667-80e68ab13773'),
	('000544.409e19f2c612458ca71de9fd1e32a11b.1032', 'f2a5b8e4-61b1-4d2c-95a3-fbb2aa47c240', '{"iss": "https://appleid.apple.com", "sub": "000544.409e19f2c612458ca71de9fd1e32a11b.1032", "email": "arnava1304@gmail.com", "provider_id": "000544.409e19f2c612458ca71de9fd1e32a11b.1032", "custom_claims": {"auth_time": 1755031146}, "email_verified": true, "phone_verified": false}', 'apple', '2025-08-08 17:08:55.612989+00', '2025-08-08 17:08:55.613038+00', '2025-08-12 20:39:06.765688+00', '15d87b2a-4d72-4a93-9f90-6e3351553538'),
	('108373333139508657644', '0dcd4f5d-2754-4d13-bb5f-4de969c0772f', '{"iss": "https://accounts.google.com", "sub": "108373333139508657644", "name": "Guillem Pico Maya", "email": "gpicomaya@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocJF3R0jOZJilwEDLf_X7MLjRasxY5l4BN8caG_65d9qMV3hfg=s96-c", "full_name": "Guillem Pico Maya", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocJF3R0jOZJilwEDLf_X7MLjRasxY5l4BN8caG_65d9qMV3hfg=s96-c", "provider_id": "108373333139508657644", "email_verified": true, "phone_verified": false}', 'google', '2025-09-01 18:51:19.938916+00', '2025-09-01 18:51:19.938972+00', '2025-09-01 18:51:19.938972+00', '61c6e7b9-5741-4cd6-a3a5-c19cd1191f13'),
	('001305.f65c3372ddae4c9c99aa6def1c31d211.2205', 'dc93a6ed-19b4-4576-8ebf-6b7d0e928ef7', '{"iss": "https://appleid.apple.com", "sub": "001305.f65c3372ddae4c9c99aa6def1c31d211.2205", "email": "ifrechoso@gmail.com", "provider_id": "001305.f65c3372ddae4c9c99aa6def1c31d211.2205", "custom_claims": {"auth_time": 1756764316}, "email_verified": true, "phone_verified": false}', 'apple', '2025-09-01 22:05:19.089526+00', '2025-09-01 22:05:19.089574+00', '2025-09-01 22:05:19.089574+00', '15b2f0ed-0902-4258-b319-b1672319b294'),
	('104681367343814027468', 'd2503c32-5e47-425c-aab1-81d2ca5c632d', '{"iss": "https://accounts.google.com", "sub": "104681367343814027468", "name": "Imma G Prats", "email": "deverdi154@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocJfS7XNrNyfTEJs9aV2cn4ahO4XFC2D4p1ZeSE_mh_nmnArs2QK=s96-c", "full_name": "Imma G Prats", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocJfS7XNrNyfTEJs9aV2cn4ahO4XFC2D4p1ZeSE_mh_nmnArs2QK=s96-c", "provider_id": "104681367343814027468", "email_verified": true, "phone_verified": false}', 'google', '2025-08-10 15:51:33.029251+00', '2025-08-10 15:51:33.029315+00', '2025-08-10 15:51:33.029315+00', '92a2b3ea-8c02-4b6d-82e8-adb17c1eea69'),
	('111045953847036705980', '15510383-6cd2-455f-9337-7e69da27678b', '{"iss": "https://accounts.google.com", "sub": "111045953847036705980", "name": "Yago Ferretti Gonzalez", "email": "yagoferretti@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocInOHiUPFKmBBTKMe-BJXZ-lXop1qzcZ5HxflxmeDh88PE_tNqb=s96-c", "full_name": "Yago Ferretti Gonzalez", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocInOHiUPFKmBBTKMe-BJXZ-lXop1qzcZ5HxflxmeDh88PE_tNqb=s96-c", "provider_id": "111045953847036705980", "email_verified": true, "phone_verified": false}', 'google', '2025-08-08 10:27:29.009288+00', '2025-08-08 10:27:29.009345+00', '2025-08-10 16:23:32.050602+00', '6671af15-3364-45ac-8ef0-2492f1501258'),
	('103647238470745305145', 'cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', '{"iss": "https://accounts.google.com", "sub": "103647238470745305145", "name": "mimmo ferretti", "email": "mimmoferretti@hotmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocLU6GKe1KrXDeNwYd_8JzXWoWU9QerWc8CwxNyYSQehLBmoYpM=s96-c", "full_name": "mimmo ferretti", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocLU6GKe1KrXDeNwYd_8JzXWoWU9QerWc8CwxNyYSQehLBmoYpM=s96-c", "provider_id": "103647238470745305145", "email_verified": true, "phone_verified": false}', 'google', '2025-08-12 13:58:38.91643+00', '2025-08-12 13:58:38.916479+00', '2025-08-12 13:58:38.916479+00', 'e05295d4-6130-474d-8bfd-af617a156850'),
	('433f5e78-f323-4d61-98be-dc7ff8e395a1', '433f5e78-f323-4d61-98be-dc7ff8e395a1', '{"sub": "433f5e78-f323-4d61-98be-dc7ff8e395a1", "email": "nickgoolbcn@gmail.com", "full_name": "Nick Gool", "email_verified": true, "phone_verified": false}', 'email', '2025-08-13 15:36:28.293288+00', '2025-08-13 15:36:28.29334+00', '2025-08-13 15:36:28.29334+00', 'a09ef16b-9885-42d2-b9ec-ddfbb1750a53'),
	('fc68eb4e-ed71-4ce2-a99e-0a28ff75a695', 'fc68eb4e-ed71-4ce2-a99e-0a28ff75a695', '{"sub": "fc68eb4e-ed71-4ce2-a99e-0a28ff75a695", "email": "gregoire@kitchensoftomorrow.com", "full_name": "Gregoire Dettai", "email_verified": true, "phone_verified": false}', 'email', '2025-08-13 16:11:10.526963+00', '2025-08-13 16:11:10.527012+00', '2025-08-13 16:11:10.527012+00', '255ad8a1-2db6-4329-93a5-03658ba8fc77'),
	('108807203569359047301', 'f2a5b8e4-61b1-4d2c-95a3-fbb2aa47c240', '{"iss": "https://accounts.google.com", "sub": "108807203569359047301", "name": "Arnav Agarwal", "email": "arnava1304@gmail.com", "picture": "https://lh3.googleusercontent.com/a/ACg8ocJGLsALk4hjkfAdy6raY13inC--pqTZtNhcLHdvcfLIiy59CQ=s96-c", "full_name": "Arnav Agarwal", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocJGLsALk4hjkfAdy6raY13inC--pqTZtNhcLHdvcfLIiy59CQ=s96-c", "provider_id": "108807203569359047301", "email_verified": true, "phone_verified": false}', 'google', '2025-08-08 17:08:33.350835+00', '2025-08-08 17:08:33.350891+00', '2025-08-19 19:29:39.376033+00', 'fb516689-e820-4361-b3be-9be61153c458'),
	('001784.5d9be38bada446bf9758c0eb5e69a9c1.1443', '890c997f-8da9-4b2d-95e0-55aa18d994d9', '{"iss": "https://appleid.apple.com", "sub": "001784.5d9be38bada446bf9758c0eb5e69a9c1.1443", "email": "qcyw8b85fz@privaterelay.appleid.com", "provider_id": "001784.5d9be38bada446bf9758c0eb5e69a9c1.1443", "custom_claims": {"auth_time": 1756910638}, "email_verified": true, "phone_verified": false}', 'apple', '2025-09-03 14:44:01.082556+00', '2025-09-03 14:44:01.082616+00', '2025-09-03 14:44:01.082616+00', 'a1441a49-a21f-467e-802a-6b396da2d357');


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."sessions" ("id", "user_id", "created_at", "updated_at", "factor_id", "aal", "not_after", "refreshed_at", "user_agent", "ip", "tag") VALUES
	('e0b3dea6-1b61-41b4-9860-05388c012f09', 'a0466a40-9577-4d72-ba89-320138b87cf5', '2025-05-25 20:52:25.8505+00', '2025-05-27 02:55:31.710963+00', NULL, 'aal1', NULL, '2025-05-27 02:55:31.710845', 'Expo/1017699 CFNetwork/1568.200.51 Darwin/24.1.0', '68.132.205.96', NULL),
	('7abfc1b9-89f6-4430-b7d6-d0e7a2bc8d17', 'be7996aa-4555-4eb1-9832-9244ad1d66a3', '2025-07-11 10:48:47.254252+00', '2025-07-11 10:48:47.254252+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1', '77.100.50.202', NULL),
	('e781a36e-4867-456b-a518-564862c7d8e8', '6de3dcac-68b8-48b3-8fd4-79f3e2ee560b', '2025-07-17 10:26:52.840798+00', '2025-07-17 10:26:52.840798+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36', '13.223.201.38', NULL),
	('dc65fa0b-0c73-4d5a-b27e-de85f0dfc8b6', 'a96d2a87-d780-4aac-9a9d-5acc35995f3d', '2025-06-11 01:24:31.36073+00', '2025-06-11 01:24:31.36073+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/137.0.7151.79 Mobile/15E148 Safari/604.1', '86.175.43.142', NULL),
	('bebbafb8-a467-4438-9216-0f77aa0508bb', 'a96d2a87-d780-4aac-9a9d-5acc35995f3d', '2025-06-11 01:25:36.272561+00', '2025-06-11 01:25:36.272561+00', NULL, 'aal1', NULL, NULL, 'Expo/1017699 CFNetwork/3826.500.131 Darwin/24.5.0', '86.175.43.142', NULL),
	('712cb8dc-f472-4a52-865d-a39daf7d88dc', 'a0466a40-9577-4d72-ba89-320138b87cf5', '2025-05-25 20:51:53.617959+00', '2025-05-25 20:51:53.617959+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36', '67.80.181.74', NULL),
	('162060ae-d11b-4718-87fb-987c7a211f08', 'cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', '2025-08-12 13:58:40.260453+00', '2025-08-19 23:51:23.615206+00', NULL, 'aal1', NULL, '2025-08-19 23:51:23.615115', 'ROA/9 CFNetwork/3826.600.41 Darwin/24.6.0', '85.190.233.116', NULL),
	('1e9ddfa5-5944-475c-be7a-a83c7ecb1f5c', 'c9cdd2fd-42f2-4813-b9b1-0fa04996d270', '2025-07-12 08:27:49.612247+00', '2025-08-12 19:48:55.425691+00', NULL, 'aal1', NULL, '2025-08-12 19:48:55.425617', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '84.76.28.178', NULL),
	('09b923cf-d49f-4db5-8c35-9dc8ab2022b8', 'ecf29cba-f0d6-4a33-a563-dcbafc920726', '2025-07-31 21:20:57.785456+00', '2025-07-31 21:20:57.785456+00', NULL, 'aal1', NULL, NULL, 'Expo/2.33.13 CFNetwork/1568.100.1 Darwin/24.5.0', '77.100.50.202', NULL),
	('b5e2b1ff-468a-4e8d-aca1-101259f58e08', '814076fa-5459-44de-a281-39617339670f', '2025-07-11 17:03:23.820095+00', '2025-07-11 17:03:23.820095+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1', '172.225.96.229', NULL),
	('91622dcd-eebb-4fa9-baba-85a806072c9f', '7acd597a-56c3-412b-b821-27e3c668cf2d', '2025-07-31 13:05:01.484814+00', '2025-08-01 08:27:57.297037+00', NULL, 'aal1', NULL, '2025-08-01 08:27:57.29696', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '84.79.72.83', NULL),
	('c9359b2b-74c2-4ec5-9610-36ea9527d694', 'f6ee302b-8550-4a16-9d40-484695473337', '2025-07-24 11:04:43.055035+00', '2025-07-24 12:21:27.163109+00', NULL, 'aal1', NULL, '2025-07-24 12:21:27.162505', 'ROA/8 CFNetwork/3826.500.131 Darwin/24.5.0', '209.203.186.10', NULL),
	('67e864a7-491f-44f3-a495-317f0df82267', 'd2503c32-5e47-425c-aab1-81d2ca5c632d', '2025-08-10 15:51:34.839387+00', '2025-09-06 21:05:05.036646+00', NULL, 'aal1', NULL, '2025-09-06 21:05:05.036574', 'ROA/9 CFNetwork/3826.600.41 Darwin/24.6.0', '83.50.161.210', NULL),
	('89e0e4f0-5a0b-4b45-b91a-9cf21f786358', 'f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c', '2025-07-09 15:25:03.934316+00', '2025-07-09 15:25:03.934316+00', NULL, 'aal1', NULL, NULL, 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1', '83.50.42.18', NULL),
	('87680c7b-3ed6-4ad9-a153-a7abfc4c6e4a', 'd56fed25-3bac-4aa7-8a61-822d8cb1cd3f', '2025-07-30 18:42:28.752104+00', '2025-07-30 18:42:28.752104+00', NULL, 'aal1', NULL, NULL, 'okhttp/4.9.2', '74.125.215.228', NULL),
	('3e7cd02f-ea6a-4c38-83a6-1f90e8add298', 'd56fed25-3bac-4aa7-8a61-822d8cb1cd3f', '2025-07-30 19:05:53.727816+00', '2025-07-30 19:05:53.727816+00', NULL, 'aal1', NULL, NULL, 'okhttp/4.9.2', '74.125.209.5', NULL),
	('99bfdee9-f3e8-4c6b-b79d-17e468147afc', '3a6970e0-6b0e-4ee0-9ad5-0b4368026f16', '2025-08-02 18:37:24.501849+00', '2025-08-09 09:52:21.908216+00', NULL, 'aal1', NULL, '2025-08-09 09:52:21.908121', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '154.161.152.215', NULL),
	('16868f67-0efc-4d6e-ac7e-45481f9afd3e', '457736da-0fb6-4bc6-a1d8-83acb178997e', '2025-08-12 16:25:58.111696+00', '2025-08-12 21:57:09.158326+00', NULL, 'aal1', NULL, '2025-08-12 21:57:09.157518', 'okhttp/4.9.2', '77.208.170.94', NULL),
	('3f8920bf-1191-478c-952d-ddd37c64f4fd', 'eb32943a-afee-4480-8a9d-c4e724668990', '2025-08-21 10:43:47.100566+00', '2025-08-22 00:02:46.889007+00', NULL, 'aal1', NULL, '2025-08-22 00:02:46.888923', 'ROA/9 CFNetwork/3826.600.41 Darwin/24.6.0', '82.132.214.127', NULL),
	('52879582-cf2e-4452-a368-6f47a9faf3f2', '62e1fa1a-5f81-465f-9cbb-418fa95526c3', '2025-07-10 16:59:49.695214+00', '2025-08-10 15:10:02.26769+00', NULL, 'aal1', NULL, '2025-08-10 15:10:02.267606', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '176.83.247.23', NULL),
	('fd815cd5-f2db-4ac6-904e-31de2f68c23c', 'f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c', '2025-07-09 15:25:43.198533+00', '2025-08-10 15:50:39.386909+00', NULL, 'aal1', NULL, '2025-08-10 15:50:39.386839', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '95.124.208.255', NULL),
	('010f87b4-6377-4fcb-b993-1cbff3ec43ff', 'bd8f6c9a-a1c5-4f32-b512-d9ce889a5a69', '2025-07-17 21:56:35.896164+00', '2025-07-21 13:04:37.643702+00', NULL, 'aal1', NULL, '2025-07-21 13:04:37.642931', 'ROA/8 CFNetwork/3826.500.131 Darwin/24.5.0', '5.90.243.107', NULL),
	('c6387dca-42f7-4430-ae3d-8242273ad96d', 'd56fed25-3bac-4aa7-8a61-822d8cb1cd3f', '2025-08-04 17:18:53.918187+00', '2025-08-04 17:18:53.918187+00', NULL, 'aal1', NULL, NULL, 'okhttp/4.9.2', '58.64.91.100', NULL),
	('dda3af5b-87cd-40f0-b4b8-dfa8d1f5dca1', 'd56fed25-3bac-4aa7-8a61-822d8cb1cd3f', '2025-08-04 17:42:30.627821+00', '2025-08-04 17:42:30.627821+00', NULL, 'aal1', NULL, NULL, 'okhttp/4.9.2', '117.0.212.70', NULL),
	('bb087956-4d62-4977-ac4f-8104a0e3f636', '3a6970e0-6b0e-4ee0-9ad5-0b4368026f16', '2025-08-09 09:53:17.906792+00', '2025-08-13 00:22:47.052454+00', NULL, 'aal1', NULL, '2025-08-13 00:22:47.052379', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '154.161.25.2', NULL),
	('946f5f8c-dca8-496c-a195-a7bbe83ab5ba', 'a8b860f9-2109-458a-a48d-8369b63f387d', '2025-08-20 09:05:38.687241+00', '2025-08-25 17:35:37.683069+00', NULL, 'aal1', NULL, '2025-08-25 17:35:37.682994', 'ROA/9 CFNetwork/3826.400.120 Darwin/24.3.0', '176.84.240.228', NULL),
	('b1914e26-7640-429d-9146-d6798e48b548', 'cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', '2025-07-15 16:10:58.131502+00', '2025-08-12 13:57:55.205472+00', NULL, 'aal1', NULL, '2025-08-12 13:57:55.205398', 'ROA/9 CFNetwork/3826.600.41 Darwin/24.6.0', '85.190.233.116', NULL),
	('c1167723-ad63-495e-84c0-2a12a76a417f', 'fc68eb4e-ed71-4ce2-a99e-0a28ff75a695', '2025-08-13 16:11:28.206196+00', '2025-08-13 16:11:28.799644+00', NULL, 'aal1', NULL, '2025-08-13 16:11:28.799571', 'okhttp/4.9.2', '88.168.205.78', NULL),
	('407ec148-017d-401b-a75f-c598846cbb7b', '433f5e78-f323-4d61-98be-dc7ff8e395a1', '2025-08-13 15:36:53.273096+00', '2025-08-14 14:51:11.722076+00', NULL, 'aal1', NULL, '2025-08-14 14:51:11.722006', 'okhttp/4.9.2', '37.29.163.150', NULL),
	('44c4e014-2931-470d-81ab-5842fe1ae11c', '15510383-6cd2-455f-9337-7e69da27678b', '2025-08-10 16:23:33.391945+00', '2025-08-26 00:51:31.732929+00', NULL, 'aal1', NULL, '2025-08-26 00:51:31.732814', 'ROA/9 CFNetwork/3826.500.131 Darwin/24.5.0', '77.100.50.202', NULL),
	('ae016cd4-6252-4c0a-be81-7ad3229c0e26', 'eb32943a-afee-4480-8a9d-c4e724668990', '2025-08-19 19:35:02.377684+00', '2025-08-19 19:35:02.377684+00', NULL, 'aal1', NULL, NULL, 'ROA/1 CFNetwork/1568.100.1 Darwin/24.5.0', '77.100.50.202', NULL),
	('13f14512-f74b-4ca6-842f-5e8ec13e86e1', 'dc93a6ed-19b4-4576-8ebf-6b7d0e928ef7', '2025-07-13 18:58:51.375237+00', '2025-09-01 22:04:37.904573+00', NULL, 'aal1', NULL, '2025-09-01 22:04:37.90381', 'ROA/9 CFNetwork/3826.600.41 Darwin/24.6.0', '83.50.161.210', NULL),
	('cea61488-8cd0-4f39-b2f3-5b5ebe8fc83d', 'dc93a6ed-19b4-4576-8ebf-6b7d0e928ef7', '2025-09-01 22:05:19.103438+00', '2025-09-02 16:05:50.461853+00', NULL, 'aal1', NULL, '2025-09-02 16:05:50.461762', 'ROA/9 CFNetwork/3826.600.41 Darwin/24.6.0', '83.50.161.210', NULL),
	('a9195594-e6b7-442d-8938-5d5eea7678a4', '814076fa-5459-44de-a281-39617339670f', '2025-07-11 17:03:43.953108+00', '2025-09-03 14:43:23.084691+00', NULL, 'aal1', NULL, '2025-09-03 14:43:23.084607', 'ROA/9 CFNetwork/3860.100.1 Darwin/25.0.0', '37.163.198.167', NULL),
	('ae0b4fb6-65dd-48f0-8f87-8495a6cdae18', '890c997f-8da9-4b2d-95e0-55aa18d994d9', '2025-09-03 14:44:01.096185+00', '2025-09-03 14:44:01.096185+00', NULL, 'aal1', NULL, NULL, 'ROA/9 CFNetwork/3860.100.1 Darwin/25.0.0', '37.163.198.167', NULL),
	('d2ac4b89-a1da-4862-9deb-e076e29f22b5', '0dcd4f5d-2754-4d13-bb5f-4de969c0772f', '2025-09-01 18:51:21.3098+00', '2025-09-04 11:07:36.912625+00', NULL, 'aal1', NULL, '2025-09-04 11:07:36.912547', 'okhttp/4.9.2', '139.47.34.101', NULL);


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO "auth"."mfa_amr_claims" ("session_id", "created_at", "updated_at", "authentication_method", "id") VALUES
	('010f87b4-6377-4fcb-b993-1cbff3ec43ff', '2025-07-17 21:56:35.940525+00', '2025-07-17 21:56:35.940525+00', 'password', '2de39b1f-7fe4-4b93-b709-241f1aec4ab7'),
	('c9359b2b-74c2-4ec5-9610-36ea9527d694', '2025-07-24 11:04:43.087096+00', '2025-07-24 11:04:43.087096+00', 'email/signup', 'd5ce7e21-5df6-436a-98d5-c8146aaf3e35'),
	('dc65fa0b-0c73-4d5a-b27e-de85f0dfc8b6', '2025-06-11 01:24:31.381404+00', '2025-06-11 01:24:31.381404+00', 'otp', '1dc03ac9-f8b8-44b5-9121-725ca52b888c'),
	('bebbafb8-a467-4438-9216-0f77aa0508bb', '2025-06-11 01:25:36.276363+00', '2025-06-11 01:25:36.276363+00', 'password', '887879a6-b316-44d9-855a-d36801b91524'),
	('87680c7b-3ed6-4ad9-a153-a7abfc4c6e4a', '2025-07-30 18:42:28.766471+00', '2025-07-30 18:42:28.766471+00', 'password', 'f8415aa5-1e0a-4c15-a640-dd3d7360f53a'),
	('3e7cd02f-ea6a-4c38-83a6-1f90e8add298', '2025-07-30 19:05:53.730098+00', '2025-07-30 19:05:53.730098+00', 'password', '03f43c0e-7248-4222-bf96-eb715e0d6abd'),
	('91622dcd-eebb-4fa9-baba-85a806072c9f', '2025-07-31 13:05:01.500165+00', '2025-07-31 13:05:01.500165+00', 'email/signup', 'b0dabdd3-be41-4cf9-b856-6e3f3558f704'),
	('09b923cf-d49f-4db5-8c35-9dc8ab2022b8', '2025-07-31 21:20:57.805768+00', '2025-07-31 21:20:57.805768+00', 'oauth', '1be0e61c-cc5a-46fb-818e-236f2b3f4e47'),
	('99bfdee9-f3e8-4c6b-b79d-17e468147afc', '2025-08-02 18:37:24.511268+00', '2025-08-02 18:37:24.511268+00', 'email/signup', '00d3c716-ad51-4b8d-bc8b-1f5b6bc70ee0'),
	('c6387dca-42f7-4430-ae3d-8242273ad96d', '2025-08-04 17:18:53.925864+00', '2025-08-04 17:18:53.925864+00', 'password', 'fd8653be-280f-49a1-8352-73bfdc713b4d'),
	('dda3af5b-87cd-40f0-b4b8-dfa8d1f5dca1', '2025-08-04 17:42:30.632211+00', '2025-08-04 17:42:30.632211+00', 'password', '139d4948-88de-4b03-88bf-237b21c419f8'),
	('89e0e4f0-5a0b-4b45-b91a-9cf21f786358', '2025-07-09 15:25:03.942622+00', '2025-07-09 15:25:03.942622+00', 'otp', '37894531-9243-4340-a49a-ca4e74431f37'),
	('fd815cd5-f2db-4ac6-904e-31de2f68c23c', '2025-07-09 15:25:43.200616+00', '2025-07-09 15:25:43.200616+00', 'password', '0ac0190c-71ab-4f73-8f79-9d1630c62700'),
	('52879582-cf2e-4452-a368-6f47a9faf3f2', '2025-07-10 16:59:49.717539+00', '2025-07-10 16:59:49.717539+00', 'otp', '828dc205-5507-42b6-9e7b-394cd2ba9476'),
	('712cb8dc-f472-4a52-865d-a39daf7d88dc', '2025-05-25 20:51:53.627698+00', '2025-05-25 20:51:53.627698+00', 'otp', '6f984140-b083-4b34-975b-bda9632fd388'),
	('e0b3dea6-1b61-41b4-9860-05388c012f09', '2025-05-25 20:52:25.853232+00', '2025-05-25 20:52:25.853232+00', 'password', '28b5e150-0617-44e9-bb4f-91c44ad58d3f'),
	('7abfc1b9-89f6-4430-b7d6-d0e7a2bc8d17', '2025-07-11 10:48:47.277721+00', '2025-07-11 10:48:47.277721+00', 'oauth', '0ea8afe2-3995-4f4c-bb35-4108d26bfafa'),
	('b5e2b1ff-468a-4e8d-aca1-101259f58e08', '2025-07-11 17:03:23.835578+00', '2025-07-11 17:03:23.835578+00', 'otp', '199ef63b-d369-404c-b746-8e507212ec91'),
	('a9195594-e6b7-442d-8938-5d5eea7678a4', '2025-07-11 17:03:43.95621+00', '2025-07-11 17:03:43.95621+00', 'password', '8b076acd-faa5-4908-bb74-53fb306dde26'),
	('1e9ddfa5-5944-475c-be7a-a83c7ecb1f5c', '2025-07-12 08:27:49.707548+00', '2025-07-12 08:27:49.707548+00', 'otp', '9e18a1a8-84f7-4972-ad38-226348c0aeba'),
	('13f14512-f74b-4ca6-842f-5e8ec13e86e1', '2025-07-13 18:58:51.421236+00', '2025-07-13 18:58:51.421236+00', 'oauth', 'fa7296df-54fa-40d4-806e-bf9bdfe3ef08'),
	('b1914e26-7640-429d-9146-d6798e48b548', '2025-07-15 16:10:58.149753+00', '2025-07-15 16:10:58.149753+00', 'otp', 'f0c1599e-6435-4a87-bf56-68fab4c79df1'),
	('bb087956-4d62-4977-ac4f-8104a0e3f636', '2025-08-09 09:53:17.909706+00', '2025-08-09 09:53:17.909706+00', 'password', 'e49d645c-792d-42bd-87e9-7dead233c520'),
	('67e864a7-491f-44f3-a495-317f0df82267', '2025-08-10 15:51:34.845736+00', '2025-08-10 15:51:34.845736+00', 'oauth', 'f2d8e76b-e7da-48e1-a70e-8fedf97f6874'),
	('44c4e014-2931-470d-81ab-5842fe1ae11c', '2025-08-10 16:23:33.396055+00', '2025-08-10 16:23:33.396055+00', 'oauth', '879a1b9b-f4d7-4783-b8ca-2e9a1e56a7b6'),
	('162060ae-d11b-4718-87fb-987c7a211f08', '2025-08-12 13:58:40.265991+00', '2025-08-12 13:58:40.265991+00', 'oauth', '0b0108d7-9b21-4d4e-b729-a04b1428d6d3'),
	('16868f67-0efc-4d6e-ac7e-45481f9afd3e', '2025-08-12 16:25:58.116242+00', '2025-08-12 16:25:58.116242+00', 'oauth', 'ec678429-9739-48f5-82e9-ab6237e25dac'),
	('e781a36e-4867-456b-a518-564862c7d8e8', '2025-07-17 10:26:52.862373+00', '2025-07-17 10:26:52.862373+00', 'otp', '32bf4ad3-c613-46e6-90af-d2021e72ad6a'),
	('407ec148-017d-401b-a75f-c598846cbb7b', '2025-08-13 15:36:53.277468+00', '2025-08-13 15:36:53.277468+00', 'email/signup', '529bb38b-cf3f-4bcd-a8f2-3ad990f76ac8'),
	('c1167723-ad63-495e-84c0-2a12a76a417f', '2025-08-13 16:11:28.211078+00', '2025-08-13 16:11:28.211078+00', 'email/signup', 'd24b7c1f-9b82-448b-95b2-4fc4147edaa8'),
	('ae016cd4-6252-4c0a-be81-7ad3229c0e26', '2025-08-19 19:35:02.384114+00', '2025-08-19 19:35:02.384114+00', 'password', 'a46c5b5f-260f-4c65-9205-fd2aa0188a6e'),
	('946f5f8c-dca8-496c-a195-a7bbe83ab5ba', '2025-08-20 09:05:38.712474+00', '2025-08-20 09:05:38.712474+00', 'password', '9dfb24d4-e3a4-46f0-8bb8-b950d55a1029'),
	('3f8920bf-1191-478c-952d-ddd37c64f4fd', '2025-08-21 10:43:47.10823+00', '2025-08-21 10:43:47.10823+00', 'password', '32e781c1-8509-441d-8946-970f5c4377a0'),
	('d2ac4b89-a1da-4862-9deb-e076e29f22b5', '2025-09-01 18:51:21.342778+00', '2025-09-01 18:51:21.342778+00', 'oauth', 'd8f5ace5-a2a9-4825-81f3-9ad687e54c02'),
	('cea61488-8cd0-4f39-b2f3-5b5ebe8fc83d', '2025-09-01 22:05:19.107037+00', '2025-09-01 22:05:19.107037+00', 'oauth', '96524202-a92f-47c8-8418-6b151645cc80'),
	('ae0b4fb6-65dd-48f0-8f87-8495a6cdae18', '2025-09-03 14:44:01.104757+00', '2025-09-03 14:44:01.104757+00', 'oauth', '561fdd19-ea03-4f7f-9146-3256e4e86e3c');


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: kitchen; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."kitchen" ("kitchen_id", "name", "type") VALUES
	('48c306e1-0814-4c91-8222-ba0993b7d66a', 'Kitchen 154', 'Team'),
	('5e047736-08a9-4ffe-8ad7-ca3f43638592', 'Tem''s', 'Team'),
	('295e6e29-929f-409c-92fa-55be7a737a90', 'arnava1304@gmail.com', 'Personal'),
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'FoodWeb Internal', 'Team'),
	('d353ecae-c56a-497f-ad99-aff7238cb44c', 'sweeney5285@gmail.com', 'Personal'),
	('20cf91d9-e07a-49ce-b9dc-1cdc67c5aed5', 'arnav@foodweb.ai', 'Personal'),
	('bc493ac0-8ecd-46f2-a7bc-b5b96c323bf6', 'yagoferretti@gmail.com', 'Personal'),
	('060259ed-faae-4798-800e-eb4b710fe716', 'apple@apple.com', 'Personal'),
	('ebc6cbcd-5699-4eb6-ba14-40c53af28cca', 'arnava1304@gmail.com', 'Personal'),
	('e6f053b8-66e9-44f4-8d68-d8df0c866e17', 'immagprats@hotmail.com', 'Personal'),
	('b6fac464-1cb7-4474-b109-917fa33d5d54', 'immagprats@hotmail.com', 'Personal'),
	('dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'maggie.q.l@hotmail.com', 'Personal'),
	('ff3f850e-a473-43d9-9520-a9959be26dbd', 'vitika.agarwal@gmail.com', 'Personal'),
	('2010da74-6360-44c5-9b63-db0cd17a6530', 'yago@foodweb.ai', 'Personal'),
	('10a99788-4b58-4e16-bc5e-c54500ec8255', 'piazzolla.luca93@gmail.com', 'Personal'),
	('aab23e0a-dfd6-4465-bdf5-f505aa0ec707', 'fabianisamat@icloud.com', 'Personal'),
	('3397babb-0eba-40b9-b6ff-7ea3a6547d05', 'arnava1304@gmail.com', 'Personal'),
	('cbbc6877-4a0e-4e99-aa87-a5cf51132629', 'ifrechoso@gmail.com', 'Personal'),
	('e3aff5a8-485d-4444-9747-70e889380a50', 'mimmoferretti@hotmail.com', 'Personal'),
	('2dd4a91d-1e2d-42d2-8675-e113d7374418', 'aa5507@columbia.edu', 'Personal'),
	('80661400-00c1-472b-9418-3bda318fcce8', 'arnava1304@gmail.com', 'Personal'),
	('00864716-7b97-4f26-bf03-21eacb19fec1', 'arnava1304@gmail.com', 'Personal'),
	('e8b08bda-1fbc-4332-9e4d-0071894a65c0', 'arnava1304@gmail.com', 'Personal'),
	('e2323643-2449-4804-aebb-6d251e7a8ab3', 'arnava1304@gmail.com', 'Personal'),
	('5dbb6986-e6a7-479a-9947-5c5a334d37aa', 'arnava1304@gmail.com', 'Personal'),
	('b60cec46-af07-4760-973b-f60ffbbdb152', 'vincent.matont@hotmail.it', 'Personal'),
	('2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'iandurkin14@gmail.com', 'Personal'),
	('ff1396ea-664c-4c80-b654-2136da431207', 'Maximé Petit', 'Team'),
	('54e863f2-e4ee-46bf-b827-fca83c351553', 'yagoferretti@gmail.com', 'Personal'),
	('e88bd223-ed21-4722-8dcb-420453caeab6', 'arnava1304@gmail.com', 'Personal'),
	('72e47938-1abf-4570-a521-8dcf90af24fd', 'google@android.com', 'Personal'),
	('9135f578-6e1c-4e43-82fe-8bc170da360b', 'maximepetitpatisserie@gmail.com', 'Personal'),
	('7599ce8e-26ae-49fb-b29f-50c9823f7bb0', '6cc4zpwnkv@privaterelay.appleid.com', 'Personal'),
	('bdc44a77-6aaf-4039-bb52-d853fdff2364', 'chris.maniakis@gmail.com', 'Personal'),
	('ccb2c02f-8418-4808-af6c-a46806429207', 'yagoferretti@gmail.com', 'Personal'),
	('cde1379e-9447-4560-a7ec-b304619ece8f', 'arnava1304@gmail.com', 'Personal'),
	('7667066b-6a66-4fbf-8902-625d535798dc', 'deverdi154@gmail.com', 'Personal'),
	('aa5f824e-051e-497a-822f-c8497480a038', 'sebastianvallejobetancourt@gmail.com', 'Personal'),
	('b81b76b5-b301-4c15-954c-c1e282bd1262', 'nickgoolbcn@gmail.com', 'Personal'),
	('016543f4-aed2-4bd4-82f6-dc99b3f4b5a2', 'gregoire@kitchensoftomorrow.com', 'Personal'),
	('36f6935a-e7de-44f5-b36c-75353d663fb6', 'adrian@colmadocarpanta.es', 'Personal'),
	('d4fd22b5-b949-4b0f-a755-301d42fb3afb', 'Colmado Carpanta', 'Team'),
	('fc0d9881-3ac0-44b7-a81b-f094ccd5063b', 'gpicomaya@gmail.com', 'Personal'),
	('dd00cb07-8b38-4c14-9385-2bdf4bef16bb', 'qcyw8b85fz@privaterelay.appleid.com', 'Personal');


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."categories" ("category_id", "name", "kitchen_id") VALUES
	('c57eac67-eec9-4ad3-b6a0-069b5e804812', 'prueba', 'bc493ac0-8ecd-46f2-a7bc-b5b96c323bf6'),
	('985230c3-1027-49a8-b15a-3e3171b19412', 'Frío', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8'),
	('e9248f49-a61a-4c38-a693-ee0e08fb8442', 'Food', 'ff3f850e-a473-43d9-9520-a9959be26dbd'),
	('34e533f4-fc06-4631-b356-151bd9ad9b0a', 'Antipasti', 'b6fac464-1cb7-4474-b109-917fa33d5d54'),
	('f195b1a3-91c7-48b0-b5b4-63cead27976e', 'Primi', 'b6fac464-1cb7-4474-b109-917fa33d5d54'),
	('9a50c278-3cf8-4172-ba9a-72b4b8afc54b', 'Secondi', 'b6fac464-1cb7-4474-b109-917fa33d5d54'),
	('6f3244b8-d18e-4531-ac6a-b3021f5e7f51', 'Ajax recipes', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6'),
	('a1f49f4f-80a6-423b-91d0-ed01bd478d17', 'Choi of cooking', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6'),
	('15ae3d5c-0205-4b58-b0d7-0f848c46c997', 'Recetas base', 'ff1396ea-664c-4c80-b654-2136da431207'),
	('5dbb7c46-0a8a-48c7-9ae4-acc25f47da80', 'Main', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
	('bf2a9fd1-6bc1-4647-a5ae-f9bb87eeba43', 'Mains', '2010da74-6360-44c5-9b63-db0cd17a6530'),
	('41526fa4-7646-4001-8641-7d33269afac1', 'Pastry', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
	('a28222de-a59c-4671-82ed-7b5746dc14dd', 'Pasta dishes', '2010da74-6360-44c5-9b63-db0cd17a6530'),
	('d5dae397-f93a-48e3-98c1-8618abb9c528', 'Starters', '2010da74-6360-44c5-9b63-db0cd17a6530'),
	('c29c7ee3-d72c-4bbf-9c57-ba872e96a773', 'Sopas', '2010da74-6360-44c5-9b63-db0cd17a6530'),
	('e0cd9b09-0b5e-4a8d-9438-5bc0b123de49', 'Postres', 'aa5f824e-051e-497a-822f-c8497480a038'),
	('9f88940c-3d5a-45f3-ae43-d72f7d7ddd19', 'Lunch', 'b81b76b5-b301-4c15-954c-c1e282bd1262'),
	('0a2c7eed-412c-4113-96ab-421222fe62bd', 'Dinner', 'b81b76b5-b301-4c15-954c-c1e282bd1262'),
	('5295067a-f114-46b4-ad0c-434a16f9ee7b', 'Sauces', 'cde1379e-9447-4560-a7ec-b304619ece8f'),
	('a4803a3d-4b1a-4454-9b5f-935493364bb2', 'Cold Prep', 'cde1379e-9447-4560-a7ec-b304619ece8f'),
	('83dc0d94-1cb9-4b11-83de-3610458e528d', 'Main Plating', 'cde1379e-9447-4560-a7ec-b304619ece8f'),
	('21e104b3-a875-40a7-b3d7-2221c2e9bb88', 'Appetiser', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
	('519cba28-2282-43d1-ab3e-3eab90f30bb2', 'Croqeuta', 'fc0d9881-3ac0-44b7-a81b-f094ccd5063b'),
	('b14ef05b-9f30-4368-80e5-5c03b63632bc', 'Bases', 'fc0d9881-3ac0-44b7-a81b-f094ccd5063b');


--
-- Data for Name: recipes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."recipes" ("recipe_id", "category_id", "recipe_name", "total_time", "serving_size_yield", "cooking_notes", "serving_item", "directions", "kitchen_id", "image_updated_at", "recipe_type", "serving_yield_unit", "fingerprint", "fingerprint_plain") VALUES
	('412dc85f-1d16-463e-9de1-59d1317193fe', 'f195b1a3-91c7-48b0-b5b4-63cead27976e', 'Spaghetti Pomodoro e basilico', '00:20:00', 90, NULL, NULL, '{"Mettere l''acqua a bollire.","Schiacciare 2 spicchi di aglio.","Aggiungere 3 cucchiai di olio quando l''olio è bollente.","Aggiungere il pomodoro.","Mettere gli spaghetti nell''acqua (11 minuti).","Aggiungere il basilico nel pomodoro (tritato o intero).","Quando è lista e cotta il sugo è pronto.","Mescolare con mezzo mestolo di acqua della pasta e un po'' di burro."}', 'b6fac464-1cb7-4474-b109-917fa33d5d54', '2025-07-12 13:18:18.380561+00', 'Dish', 'g', NULL, NULL),
	('a466ddc5-4cc3-4bb3-aea9-b60df3ee2346', NULL, 'Chocolate Tart', '00:30:00', 100, NULL, NULL, NULL, 'bdc44a77-6aaf-4039-bb52-d853fdff2364', NULL, 'Dish', 'g', NULL, NULL),
	('046cf913-50c9-43b8-b2d8-ff483fffa7a6', NULL, 'H. Mató', '00:30:00', 1, NULL, NULL, '{"Preparar la mezcla según las instrucciones anteriores."}', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', '2025-07-10 17:04:03.497378+00', 'Dish', 'x', NULL, NULL),
	('c71a2128-59a7-4e9e-8ae3-6a51e7f2234f', 'a1f49f4f-80a6-423b-91d0-ed01bd478d17', 'Korean Ssamjang Dip', '00:10:00', 1, 'You can serve this dip with raw vegetables or use it as a dip for Korean-style steamed dishes.', NULL, '{"In a blender, combine the jalapeño, gochujang, doenjang or white miso paste, garlic, scallions, soy sauce, sesame oil, rice vinegar, and sugar (if using). Blend until smooth.","Taste and adjust the seasoning as needed.","Serve with raw vegetables."}', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', NULL, 'Dish', 'cup', NULL, NULL),
	('57159ab4-f635-4158-afb9-18a7854fa0a3', 'e9248f49-a61a-4c38-a693-ee0e08fb8442', 'Crispy Fish Sticks with Mushy Peas', '00:30:00', 4, 'Ensure fish sticks are golden and crispy.', NULL, '{"Serve crispy fish sticks with mushy peas."}', 'ff3f850e-a473-43d9-9520-a9959be26dbd', '2025-07-11 10:53:49.102491+00', 'Dish', 'x', NULL, NULL),
	('76d10c78-8ee0-4998-a849-530a834a8a5b', '5dbb7c46-0a8a-48c7-9ae4-acc25f47da80', 'Leek, Leek', '01:00:00', 1, NULL, 'leek', '{"Poach the leeks in white stock and miso until soft.","Make cauliflower foam by cooking cauliflower in butter, blending with cream, and straining.","Prepare leaf sauce by boiling green stems from leek in water, blending, and reducing.","Serve poached leeks with cauliflower foam and leaf sauce."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', '2025-07-19 20:13:04.356626+00', 'Dish', 'x', NULL, NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '9f88940c-3d5a-45f3-ae43-d72f7d7ddd19', 'Pollo ripieno arrosto', '01:00:00', 1, NULL, NULL, '{"Cominciate col dare alle salsicce e alle rigaglie mezza cottura nel burro.","Bagnandole con un po'' di brodo se occorre.","Conditele con poco sale e poco pepe a motivo delle corre.","Levate asciutte e nell''umido che resta gettate una midolla di pane.","Per ottenere con un po'' di brodo due cucchiaiate di papa soda.","Spellate le salsicce, tritate con cura."}', 'b81b76b5-b301-4c15-954c-c1e282bd1262', '2025-08-14 14:55:01.657618+00', 'Dish', 'x', NULL, NULL),
	('0d16c807-a8eb-4cc6-ae5a-05f5660dbb45', NULL, 'Cauliflower Shepherd''s Pie', '00:50:00', 1, 'Vegan and Vegetarian: Use cooked lentils instead of ground meat.', 'serving', '{"Preheat oven to 350°F (177°C).","Transfer the meat mixture to a casserole or pie dish and distribute into an even layer.","Top with the cauliflower mash and spread it evenly across the top.","Place in the oven and bake for 20 minutes.","Turn the oven to a low broil and broil for 10 minutes or until golden.","Remove from oven and serve."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Dish', 'x', NULL, NULL),
	('74c79adc-1130-4e88-a8e1-5900dac84be7', '41526fa4-7646-4001-8641-7d33269afac1', 'Tiramisù', '02:30:00', 1, NULL, NULL, '{"Once ready, get a generous spoon of cream for the base of your tiramisù in a baking dish size around 30x20 cm.","Soak for few seconds the savoiardi biscuits both sides into the coffee already cold and sweetened as you prefer.","Distribute the soaked savoiardi on the top of the cream, all in the same direction and level.","Add again on the top the cream, then the savoiardi and keep going on the same till you will made the layers that you like.","Give more attention on the last layer of cream, since will be the presentation of your tiramisù.","Put on the top the bitter cocoa powder.","Put the tiramisù in the fridge for at least a couple of hours."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', '2025-08-01 18:38:51.502654+00', 'Dish', 'x', NULL, NULL),
	('8ee812fc-f52f-488d-98d0-af4b1fea16d3', NULL, 'Eclair Tiramisú', '02:00:00', 1, NULL, NULL, '{"Prepare choux pastry and pipe into éclairs.","Bake until golden.","Fill with coffee cremoso.","Top with bizcocho terengue."}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Dish', 'x', NULL, NULL),
	('39bd92b0-1b00-4ac2-b171-26aecda76102', '83dc0d94-1cb9-4b11-83de-3610458e528d', 'Leek Dish', '00:45:00', 300, 'Ensure leeks are tender and cauliflower foam is smooth.', NULL, '{"Serve poached leek with cauliflower foam and leek sauce."}', 'cde1379e-9447-4560-a7ec-b304619ece8f', '2025-08-19 19:34:22.714652+00', 'Dish', 'g', NULL, NULL),
	('62208202-6c71-4163-a408-0ad0a7f16915', 'a28222de-a59c-4671-82ed-7b5746dc14dd', 'Leek, Leek', '01:30:00', 200, NULL, NULL, '{"Poach the leeks.","Make the leek sauce.","Prepare the cauliflower foam.","Serve together."}', '2010da74-6360-44c5-9b63-db0cd17a6530', '2025-08-05 15:30:39.597953+00', 'Dish', 'g', NULL, NULL),
	('5b66fd41-9a10-45b6-bde6-1e106a8cf143', NULL, 'Carrot Cake', '01:00:00', 1, NULL, 'slice', '{"Antes de montar la crema, tiene que descongelarlos del todo, y pintar un poco de almíbar para humedecer el bizcocho."}', '7667066b-6a66-4fbf-8902-625d535798dc', NULL, 'Dish', 'x', NULL, NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', NULL, 'Salsa Gialla per Pesce Lessso', '00:20:00', 100, 'The sauce should be smooth and creamy. Adjust seasoning as needed.', NULL, '{"In a small saucepan, heat 20g of butter over low heat.","Add 20g of flour and mix well to create a roux.","Cook for a few minutes until the roux is lightly golden.","Gradually add 400g of fish cooking liquid, whisking continuously to avoid lumps.","Bring the mixture to a boil, then reduce the heat and simmer for a few minutes until it thickens.","Remove from heat and stir in the egg yolk mixed with a squeeze of lemon juice.","Season with salt and pepper to taste.","Serve hot."}', 'e3aff5a8-485d-4444-9747-70e889380a50', NULL, 'Dish', 'ml', NULL, NULL),
	('0b64294d-c603-4ebd-9a6d-181ebbc37fc2', NULL, 'Leek Dish', '01:00:00', 1, NULL, 'leek', '{"Serve the poached leek with cauliflower foam and leek sauce."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Dish', 'x', NULL, NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', NULL, 'Roasted Butternut Squash Soup', '00:40:00', 250, 'Save all leftover peels and trimmings from the carrots, onion, and garlic for later use.', NULL, '{"Preheat the oven to 200°C (392°F).","Cut the butternut squash in half lengthwise, remove the seeds (set them aside for later), and roast skin side down.","Peel and chop carrots, onion, and garlic.","Drizzle olive oil, season with salt and pepper, and roast veggies for 45-50 minutes.","Dice a portion of roasted butternut squash for Butternut Squash Risotto & save for recipe 7.","Roast leftover butternut squash seeds for 10-15 minutes.","Blend roasted vegetables until smooth, adjusting consistency with broth or water.","Heat soup in a pot, season to taste, and serve hot with roasted seeds and olive oil garnish."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', '2025-08-21 10:44:39.697975+00', 'Dish', 'ml', NULL, NULL),
	('c8200eb7-6285-42a2-af93-f50e51cf7858', NULL, 'Sugo di Pomodoro e Basilico', '00:15:00', 1, NULL, NULL, '{"Schiacciare 2 spicchi di aglio.","Aggiungere 3 cucchiai di olio quando l''olio è bollente.","Aggiungere il pomodoro.","Aggiungere il basilico nel pomodoro (tritato o intero)."}', 'b6fac464-1cb7-4474-b109-917fa33d5d54', NULL, 'Preparation', 'x', NULL, NULL),
	('de2c3bd6-4d72-4598-ba8d-bd401e505941', NULL, 'Leek Sauce', '00:30:00', 1, NULL, NULL, '{"Tightly braised with water.","Cook for 1 hour and 30 minutes.","Pass through a sieve.","Reduce until almost dry."}', '2010da74-6360-44c5-9b63-db0cd17a6530', '2025-08-07 09:23:25.552816+00', 'Preparation', 'x', NULL, NULL),
	('df188431-52e2-4c2a-bee9-501026c15dc3', NULL, 'Chocolate Ganache', '00:15:00', 1, NULL, NULL, '{"Warm up the cream to 90oC","Pour over the chocolate and allow to melt, mix with mariz","Emulsify with bamix without incorporating air and regrigerate"}', 'bdc44a77-6aaf-4039-bb52-d853fdff2364', NULL, 'Preparation', 'x', NULL, NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', NULL, 'Crema Montada de Zanahoria', '00:20:00', 1, NULL, NULL, '{"Licuar las zanahorias hasta obtener 700ml.","En un cazo amplio agregar el licuado con la glucosa, reducir a la mitad de su volumen."}', '7667066b-6a66-4fbf-8902-625d535798dc', NULL, 'Preparation', 'x', NULL, NULL),
	('d5c97843-b2e2-4b7d-9332-2a239387a136', NULL, 'Mascarpone Cream', '00:15:00', 1, NULL, NULL, '{"Carefully separate the egg whites from the yolks.","With the electric whips, mix the yolk well first, adding half of the total amount of sugar you have until it is lighter and fluffy.","Clean your electric whips because you have to mix the egg white with the other half of the sugar.","The result will be firm, till moving up and down the bowl the cream will not move!","Gradually, spoon by spoon, add the white egg cream with the yolk cream made earlier; mix properly softly from top to bottom."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', NULL, 'Pickling Liquid', '00:20:00', 1, NULL, NULL, '{"Make a sachet d''epices with the mustard, peppercorn, and garlic.","In a pot, combine the vinegar, water, salt, chili flakes, and the sachet.","Bring to a boil, then cool down. Add dill."}', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', NULL, 'Preparation', 'x', NULL, NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', NULL, 'Turkey and Vegetable Mixture', '00:20:00', 1, NULL, NULL, '{"Heat half of the olive oil in a large frying pan over medium heat.","Add the onions and garlic, cook for 5 minutes or until onions are translucent.","Add the meat, and cook until browned.","Add the mushrooms, carrots, celery, Italian seasoning, and salt.","Continue to cook for a few minutes, until the meat is cooked through.","Remove from heat."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('eba91d21-3ae0-4b0f-aae6-ed99f4d1694e', NULL, 'Mezcla de Mascarpone y Gelatina', '00:10:00', 1, NULL, NULL, '{"Mezclar mascarpone y gelatina."}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Preparation', 'x', NULL, NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', NULL, 'Stuffing Mixture', '00:15:00', 1, NULL, NULL, '{"Combine the sausage, chicken liver, crest, and gizzards.","Add a small ball of truffles or dried mushrooms.","Add a pinch of nutmeg.","Mix in an egg."}', 'b81b76b5-b301-4c15-954c-c1e282bd1262', NULL, 'Preparation', 'x', NULL, NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', NULL, 'Pasta Choux', '00:30:00', 1, NULL, NULL, '{"Combine water, milk, butter, salt, and sugar in a pot.","Bring to a boil, then add flour.","Cook until the dough forms a ball.","Transfer to a mixer and add eggs gradually."}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Preparation', 'x', NULL, NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', NULL, 'Cremoso de Café', '00:30:00', 1, NULL, NULL, '{"Mix milk, cream, eggs, and sugar.","Add Dulcey and gelatine.",Emulsify.}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Preparation', 'x', NULL, NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', NULL, 'Mezcla de Ingredientes', '00:30:00', 1, NULL, NULL, '{"Mezclar leche y nata a 40°C.","Añadir los ingredientes secos.","Calentar a 83°C.","Añadir el sarro y el mató."}', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', NULL, 'Preparation', 'x', NULL, NULL),
	('cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd', NULL, 'Mushy Peas', '00:10:00', 1, NULL, NULL, '{"Boil or steam frozen peas until tender.","Mash with butter and season with salt."}', 'ff3f850e-a473-43d9-9520-a9959be26dbd', NULL, 'Preparation', 'x', NULL, NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', NULL, 'Crema Mascarpone', '00:30:00', 1, NULL, NULL, '{}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Preparation', 'x', NULL, NULL),
	('4bc9f164-9169-4b0a-bacb-3af5f5c34f27', NULL, 'Cauliflower Foam', '00:15:00', 1, NULL, NULL, '{"Butter cauliflower to get a nice colour.","Add cream and cook till very soft.","Blend till smooth."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('214ea2d4-b92a-4b78-af05-7e09f66f5461', NULL, 'Coffee', '00:05:00', 1, NULL, NULL, '{"Prepare 4 full cups of coffee."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('922c20fe-e228-498c-a850-3303986ac0cb', NULL, 'Poached Leek', '00:30:00', 1, NULL, NULL, '{"Have small ''noves with a wine''.","Stock and poach till soft."}', '2010da74-6360-44c5-9b63-db0cd17a6530', NULL, 'Preparation', 'x', NULL, NULL),
	('3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369', NULL, 'Cauliflower Foam', '00:20:00', 1, NULL, NULL, '{"Butter cauliflower to get a nice colour.","Add cream and cook till very soft.","Blend till smooth."}', '2010da74-6360-44c5-9b63-db0cd17a6530', NULL, 'Preparation', 'x', NULL, NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', NULL, 'Bizcocho de Zanahoria', '00:30:00', 1, NULL, NULL, '{"Mezclar el huevo entero con el azúcar, envasar al vacío.","Calentar en la Roner a 58 grados durante 20 minutos.","Poner el huevo a montar con varillas hasta que se enfríe la mezcla.","Tamizar las partes secas al huevo montado, moverlo suavemente con una lengua.","Pasar la masa al molde redondo engrasado y cocinar a 180 grados, H25, V4 durante unos 30 minutos.","Antes de sacar del horno, pinchar el medio para asegurar que esté bien cocinado.","Enfriar bien del todo, quitar la costra del borde y encima, partir el bizcocho horizontalmente por la mitad, reservar en congelador."}', '7667066b-6a66-4fbf-8902-625d535798dc', NULL, 'Preparation', 'x', NULL, NULL),
	('436e84a1-b015-4d80-8099-101f9a568a72', NULL, 'Cauliflower Mash', '00:15:00', 1, NULL, NULL, '{"Place cauliflower florets in a medium-sized saucepan, cover with water, and bring to a boil.","Let the florets boil until they are soft, about 15 minutes.","Drain the cauliflower and discard cooking water.","Return the cauliflower to the pot and add the other half of the olive oil and a sprinkle of salt.","Mash well until the cauliflower becomes almost like a puree."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', NULL, 'Crispy Fish Sticks', '00:15:00', 1, NULL, NULL, '{"Cut fish fillets into stick shapes.","Dredge fish sticks in flour, then dip in beaten eggs, and coat with breadcrumbs.","Fry until golden and crispy."}', 'ff3f850e-a473-43d9-9520-a9959be26dbd', NULL, 'Preparation', 'x', NULL, NULL),
	('bbd2273a-31e5-41b6-99f9-bc9836932d59', NULL, 'Caramelo Miso Mixture', '00:20:00', 1, NULL, NULL, '{"Combine white chocolate, milk, honey, butter, and salt in a saucepan.","Heat the mixture over medium heat, stirring constantly.","Bring the mixture to a boil, then reduce heat and simmer for 5 minutes.","Remove from heat and let cool."}', 'aa5f824e-051e-497a-822f-c8497480a038', NULL, 'Preparation', 'x', NULL, NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', NULL, 'Ssamjang Dip', '00:05:00', 1, NULL, NULL, '{"Blend all ingredients until smooth."}', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', NULL, 'Preparation', 'x', NULL, NULL),
	('3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', NULL, 'Poached Leek', '00:15:00', 1, NULL, NULL, '{"Make small nicks in the leek with a knife.","Poach in white wine and stock until soft."}', 'cde1379e-9447-4560-a7ec-b304619ece8f', NULL, 'Preparation', 'x', NULL, NULL),
	('03b059cf-caf7-413e-9313-a52e546f2908', NULL, 'Mezcla de Nata y Azúcar', '00:05:00', 1, NULL, NULL, '{"Mezclar nata y azúcar."}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Preparation', 'x', NULL, NULL),
	('d5a1e773-7b8c-4667-b069-aff4011a3e71', NULL, 'Cauliflower Foam', '00:10:00', 1, NULL, NULL, '{"Cook cauliflower in butter until tender.","Blend with cream until very soft and smooth."}', 'cde1379e-9447-4560-a7ec-b304619ece8f', NULL, 'Preparation', 'x', NULL, NULL),
	('0688ba42-e321-42b1-a29e-78a38ce7825f', NULL, 'Bizcocho Terengue', '00:20:00', 1, NULL, NULL, '{"Mix curd, sugar, and egg yolks.","Add dry ingredients and mix.","Bake at 180°C."}', 'ff1396ea-664c-4c80-b654-2136da431207', NULL, 'Preparation', 'x', NULL, NULL),
	('0d03d7e2-d617-4e73-b350-0521b9ff8323', NULL, 'Leek Sauce', '00:20:00', 1, NULL, NULL, '{"Tightly bundle leek greens.","Cook in water for 1 hour 30 minutes.","Pass through a sieve.","Reduce remaining stock to desired consistency."}', 'cde1379e-9447-4560-a7ec-b304619ece8f', NULL, 'Preparation', 'x', NULL, NULL),
	('096fce76-eb2a-4fca-a30e-466e90c7347c', NULL, 'Leaf Sauce', '00:10:00', 1, NULL, NULL, '{"Tightly bundle leek greens.","Boil in water for 1-1.5 hours.","Pass through a sieve.","Reduce remaining stock to desired consistency."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('7522635d-6321-4529-958e-a76b9198bc14', NULL, 'Poached Leek', '00:20:00', 1, NULL, NULL, '{"Make small holes in the leek with a knife.","Stock and poach until soft."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL),
	('e5ebfe86-99be-4a62-9468-47ea78f86e05', NULL, 'Leek Sauce', '00:10:00', 1, NULL, NULL, '{"Tightly boil the green stems of leek with water.","Cook for 1-1.5 hours.","Pass through a sieve.","Reduce until it reaches the desired consistency."}', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', NULL, 'Preparation', 'x', NULL, NULL);


--
-- Data for Name: components; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."components" ("name", "component_id", "kitchen_id", "component_type", "recipe_id") VALUES
	('leek', 'c70f8b84-19ee-4146-b7db-732a2258ba73', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('white miso', '5f9b0714-f3dc-4720-89ac-0ed7cbdcca8c', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('vegetable stock', '718cb336-aad9-4479-bf8d-0bb5e95ce697', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('sal', '4cf07418-720d-4d92-a899-f046df18fdda', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('butter', '9bb04a06-aa40-4987-83ac-0491a8434617', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('cauliflower', 'bdaadae9-f355-4493-a91b-36fd643d215c', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('cream', 'b5f29b90-d84c-499e-8238-fd37da38fdf8', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('eggs', 'a01325d4-5984-4f6a-a35b-0c31ab713060', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('sugar', '4b7e8a5e-3b4b-4816-91eb-36016d019e2a', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('mascarpone cheese', '9e79bee3-d6be-499a-8b87-6df5e7210ab9', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('fish fillets', 'bf4e92df-229e-4b03-91c5-0e195f4ddd0d', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('savoiardi biscuits', '450436ad-7471-4e54-b2af-64c395568055', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('coffee', '2d919b4b-9cd4-4f1a-bbb9-74e8054d2049', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('bitter cocoa powder', 'a6e1453b-ff47-4aae-a75a-834f5db40728', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('breadcrumbs', 'beddd9dc-49ad-4245-8840-ae5d15ab0ab2', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('sal', '0565be00-076b-4aa2-ad38-91e2dde6f062', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('eggs', '133a5f1a-d51b-4f5d-bd6e-53fbb72b2bb6', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('flour', '08a9337d-9917-4239-bce5-08ce58a716ae', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('butternut squash', 'c4d5cb44-41a8-494f-8f45-05f02176e955', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('carrots', '0a88f9ef-a895-4b30-9010-98d0f6c4785a', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('onion', '89347441-ded6-4758-8563-d7e6d4428c15', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('garlic', 'aaa6c03d-ea1c-4dcf-ad39-0197f03cc63b', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('olive oil', 'a907c585-f9cc-4d1b-9a72-bdb9182e0562', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('salt', '2670f74a-9c4a-40b1-976f-ac4f88cb501d', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('pepper', '958d5830-ad7f-4108-afa7-d624f1b356cd', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('salt', '37935488-601e-4b74-a2d8-b0f460feeec9', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('extra lean ground turkey', '8dfdeaa4-2661-4c7e-9f06-366d20d65403', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('yellow onion', '0963cc2e-e17b-4646-88a3-41a17b181adb', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('mushrooms', '3a5d30f3-e349-4581-af3a-a3ef7f0c54b8', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('celery', '4cc59132-7397-4fa3-82e6-6033720d0743', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('italian seasoning', '3ac6f64e-26ad-46a0-be41-ee7f045774f0', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('sea salt', 'b3ac9df1-f21b-42dc-8bee-274d7f5286eb', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('extra virgin olive oil', '8206414f-d29c-4767-98b9-37d4562f3355', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('white miso', '6bd6070e-53a1-4c0e-af74-98aad4f2fc9d', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Raw_Ingredient', NULL),
	('butter', '8e66b973-71ad-4c9e-aa57-73c72b21c0ce', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Raw_Ingredient', NULL),
	('pepper', 'b76e181a-fa94-4d2f-ab08-1d94a7da9692', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('azúcar de flor de coco', '5b0c7ae8-cbb5-4ebe-a0cb-98eee18ac5ab', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('huevos', 'c24f7c9a-a596-47ee-96a3-4cc06001563b', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('mezcla de especias', '035fbcee-541b-4594-8e4f-0bde74899bc2', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('nata 35%mg', '52eb11d2-83e9-4a89-a73a-b067ac388d0e', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('leche', '80e6120b-a237-42d1-9083-71df2765adfd', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('choco blanco', '8833d88e-4af5-43d3-a635-9a6209f4f0c9', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('gelatina', 'd178d591-838d-4d07-b8fe-0156f06ec6d6', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('colorante amarillo', '8c0dd368-519e-49aa-bbc5-66c72d291a91', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('frozen peas', '5fb46bc4-9ebb-404b-8abb-aea24ddfca43', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('nata', '7887ed5a-14a6-4139-ae99-a10d7dde3698', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('dextrosa', '85e9ac1d-f90e-4245-bccd-f6bcdfe895a8', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('azúcares', 'dcbfcacc-14ef-40e5-9e71-82b2ebdde77e', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('mató', 'a91ce3b0-e5c6-4c75-9291-ee4dfd652829', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('estabilizante', '79a23778-6a71-4c89-9811-d406491c7056', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Raw_Ingredient', NULL),
	('butter', '5dfac492-5371-4855-aa6e-882eaab83b53', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Raw_Ingredient', NULL),
	('butter', '604146ff-a2ee-4927-925a-1ead9058a3bc', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('flour', '97164d98-e925-4c71-b687-5d56999744c7', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('egg yolks', '136c4469-76df-4d32-baf7-5255d45089af', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('lemon', 'e3d9ccae-ab00-44b0-bca6-39e371c680dd', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('salt', 'f825d544-29da-4b6d-8847-cabc57a2300c', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('white chocolate', '52d673c4-de2b-4c2c-bb8a-b389b13622cf', 'aa5f824e-051e-497a-822f-c8497480a038', 'Raw_Ingredient', NULL),
	('honey', '18eefb9d-543d-43dc-9ee1-d3f01593f77d', 'aa5f824e-051e-497a-822f-c8497480a038', 'Raw_Ingredient', NULL),
	('butter', '4d6a3e90-0982-4e8e-a9c5-298bb5db5182', 'aa5f824e-051e-497a-822f-c8497480a038', 'Raw_Ingredient', NULL),
	('salt', '1d91ae38-efe8-495b-b830-8d127962c8ce', 'aa5f824e-051e-497a-822f-c8497480a038', 'Raw_Ingredient', NULL),
	('spaghetti', 'e1ff35de-02d2-4453-8241-d1d6f1e9e5e7', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Raw_Ingredient', NULL),
	('tomato', 'e2da5708-64e2-4e0a-b63b-16d51b6e3b5d', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Raw_Ingredient', NULL),
	('garlic', 'f046b00a-644f-4dec-84c6-9cee72cdcfe3', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Raw_Ingredient', NULL),
	('olive oil', '178bc85d-9222-4491-ac9c-0050471d2932', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Raw_Ingredient', NULL),
	('basil', 'd3959d7b-02f9-4bb2-af9a-7216cabd039f', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Raw_Ingredient', NULL),
	('butter', '3a5193c0-c7dd-48db-8833-e3579d2eaa9f', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Raw_Ingredient', NULL),
	('vegetable stock', '57802cb6-c5b1-4543-a348-828247181453', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Raw_Ingredient', NULL),
	('cauliflower', '43ed9eb8-5eaf-4e6d-a3ad-69a9e8d25f21', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Raw_Ingredient', NULL),
	('Chocolate 55%', '982bb972-29f7-4352-a361-74655299a7c3', 'bdc44a77-6aaf-4039-bb52-d853fdff2364', 'Raw_Ingredient', NULL),
	('Whipping Cream 35%', '7995d592-abdb-4dcd-8617-f1cc0d8ccdc7', 'bdc44a77-6aaf-4039-bb52-d853fdff2364', 'Raw_Ingredient', NULL),
	('harina floja', '0c44198c-3a00-49ce-a67e-17861e35b733', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('zanahoria', '3f5da04c-3de2-4690-8c58-bd460914edd6', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('vaina de vainilla', 'f9b95743-d921-4f82-92dd-c38af215a98e', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('fish cooking liquid', '21fc70b2-bd21-4dba-bd0c-c54bd7c9a69b', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('milk', 'bb73bc38-fb95-42d5-8952-4b19d93822be', 'aa5f824e-051e-497a-822f-c8497480a038', 'Raw_Ingredient', NULL),
	('chicken', '59ba2856-6abf-40f1-8a06-f1b00cd05d53', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('sausage', '9e29a99c-4a03-4d05-8c09-70ac9e60207e', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('chicken liver', '478278ac-8159-4972-9afa-80b5da3d0878', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('chicken crest', 'e4f6bb2f-99aa-4a43-9a84-6333032dd16c', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('chicken gizzards', '9b66ca37-4af5-4531-bdc6-df9ca4b016bd', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('truffles', '3f6b8518-dd15-4d64-82e3-56ece7be13e9', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('nutmeg', '68896111-aff2-4105-91d9-480601f1ba42', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('butter', '3ba1e5a5-15b4-45e1-b4fc-48a7c297b84f', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('pepper', '40f8b1b3-77d6-43e7-ad75-9182ef830d6b', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('white wine', '8109cd45-db10-48c2-849a-5786226dae44', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('water', 'c3fd075a-9b54-44ee-a533-850e75c83325', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('leek', '895359d5-c043-45ea-a7c8-8179fee53db1', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Raw_Ingredient', NULL),
	('cream', '63463616-94b3-47ec-8be3-7eec3a3f599c', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Raw_Ingredient', NULL),
	('polvo levadura royal', '119d2a50-4342-4400-be28-f9bec58c94aa', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('glucosa líquida', '58ccb6cf-429a-401c-b3dc-9a89bc4e4670', '7667066b-6a66-4fbf-8902-625d535798dc', 'Raw_Ingredient', NULL),
	('pepper', '19272280-8cd2-42fe-98c8-6d13b089cea6', 'e3aff5a8-485d-4444-9747-70e889380a50', 'Raw_Ingredient', NULL),
	('dried mushrooms', '7090a837-e93a-4844-aac8-2ad18ccb4750', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('egg', 'b051a071-aa10-46dd-b4e1-1a265bb8b4d1', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('broth', '28754d06-6609-4287-a539-cf65d0c24e73', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('salt', '8a75c368-9445-472e-a083-aaf84afe6673', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('water', '2439f7b2-bc65-495b-8081-449312930407', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('apple cider vinegar', 'bc06aad6-aff0-4ca4-8535-95cd05bc4f2a', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('salt', 'ec35f115-3d63-4e12-94a8-6dd1c22beec4', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('yellow mustard seed', 'c2d969e8-2667-4066-bd05-dca75d0f007f', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('black peppercorn', '0eca83bc-aef2-4149-bde4-e18024b2c56a', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('red chili flakes', '3992d161-1033-4c27-9376-88370cda94f8', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('shallot', '2f2f6ceb-d34f-4f41-b61e-4b91d6d0e992', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('garlic', '4adacd16-bf40-41d9-84c8-d3e07f544771', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('dill', '1015d290-9436-4831-871f-ad69ab0aff33', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('cucumber', '5a38c103-ba16-49ef-8d44-ab55db9de90b', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('bread crumb', '9bdb38fa-aba2-4eaf-adf9-e1353c99a3e6', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Raw_Ingredient', NULL),
	('leek', '75c24432-e7cf-4b99-ba4c-1fc33b51b062', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('white miso', '50568ee9-0804-4e34-9c57-da82255dcef8', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('vegetable stock', 'e7d9a313-29ef-4f27-bed8-5d0bee0c281a', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('jalapeño', '548f2f4a-a023-4947-99c7-f03e156632f2', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('gochujang', '821a10e4-1dd5-4d9e-a036-655af28cff98', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('doenjang', '400c76f3-35af-4dca-adf0-c5e6764b6cde', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('scallions', 'e79ec050-3aae-4b9d-88eb-3ad5fee3e542', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('soy sauce', 'f7adbec0-9c31-4f34-a6de-c0ffdad96ce6', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('sesame oil', 'f7a837e1-8a6f-44e7-aa09-3890dbae8810', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('rice vinegar', '25376124-9462-4d1f-81cc-9b3b7e09b1f5', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('sugar', '3a40248d-334b-485a-87d6-24de429d7d50', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Raw_Ingredient', NULL),
	('mascarpone', 'f2ac327b-6abc-4313-9b21-576cc214f92e', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('gelatina', '946f20c4-8fde-4f03-95e0-b028770c1478', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('nata', '5994d39d-5274-43c7-a5a5-12ac3856aa58', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('azúcar', '08b51058-971e-4f60-86c7-6374238ef989', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('agua', 'b139ae68-e456-4b97-8955-58cf4cdf0f3e', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('leche', 'b4e15865-667f-4760-ae0f-80f45313a4ed', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('mantequilla', '60a34f12-ffb2-4de9-a9e8-3bcea79796f7', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('harina', 'a9386b71-639e-4267-b41c-c7175894ff15', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('huevos', 'c8b289fb-6860-4f07-946c-204d705ec7b7', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('sal fina', '56c584ad-adc5-4a5f-897e-78d17d0364f7', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('cuajada', '9fff95bc-f887-4766-8a96-40e985b5758a', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('yema de huevo', '248eba5c-0253-4306-873c-05764c5397c9', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('maizena', '9d8e2e18-e8c7-4fa3-b2bd-885732d380f4', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('dulcey', 'a34b8c0b-0f0a-4bd2-af38-1ff73c55b3f1', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('Vainilla', 'ae82dce6-4929-4b83-83c7-5e8fb0444228', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('Nata fría', '80b8437e-6d8d-42ce-96c2-3c7c7b946418', 'ff1396ea-664c-4c80-b654-2136da431207', 'Raw_Ingredient', NULL),
	('cauliflower', 'e1f16002-72c0-4799-8c4e-583cecf727cd', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('leek greens', '38e30063-2710-41d7-ade2-57883db76ffb', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('water', '4d2150da-8fb6-4740-b093-0255b5305f8f', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Raw_Ingredient', NULL),
	('butter', '6d050e35-43d8-48fb-b35d-8ae1219f4823', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('cream', 'c708aee7-e214-47e3-81c6-0b04852aefb3', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Raw_Ingredient', NULL),
	('Sugo di Pomodoro e Basilico', 'c8200eb7-6285-42a2-af93-f50e51cf7858', 'b6fac464-1cb7-4474-b109-917fa33d5d54', 'Preparation', 'c8200eb7-6285-42a2-af93-f50e51cf7858'),
	('Leek Sauce', 'de2c3bd6-4d72-4598-ba8d-bd401e505941', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Preparation', 'de2c3bd6-4d72-4598-ba8d-bd401e505941'),
	('Chocolate Ganache', 'df188431-52e2-4c2a-bee9-501026c15dc3', 'bdc44a77-6aaf-4039-bb52-d853fdff2364', 'Preparation', 'df188431-52e2-4c2a-bee9-501026c15dc3'),
	('Crema Montada de Zanahoria', '568e5750-e786-4e22-bf9e-e4514fe1d817', '7667066b-6a66-4fbf-8902-625d535798dc', 'Preparation', '568e5750-e786-4e22-bf9e-e4514fe1d817'),
	('Mascarpone Cream', 'd5c97843-b2e2-4b7d-9332-2a239387a136', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', 'd5c97843-b2e2-4b7d-9332-2a239387a136'),
	('Pickling Liquid', 'fa1bdca2-c244-48a5-b3ab-a1f16562677c', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Preparation', 'fa1bdca2-c244-48a5-b3ab-a1f16562677c'),
	('Turkey and Vegetable Mixture', 'b579f6f2-278e-4690-bc76-1d64e83f9eaf', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', 'b579f6f2-278e-4690-bc76-1d64e83f9eaf'),
	('Mezcla de Mascarpone y Gelatina', 'eba91d21-3ae0-4b0f-aae6-ed99f4d1694e', 'ff1396ea-664c-4c80-b654-2136da431207', 'Preparation', 'eba91d21-3ae0-4b0f-aae6-ed99f4d1694e'),
	('Stuffing Mixture', 'c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', 'b81b76b5-b301-4c15-954c-c1e282bd1262', 'Preparation', 'c3f6ce60-4115-4b71-bfbe-a60dfc15cbed'),
	('Pasta Choux', 'a9a63d8d-437a-4d5b-a580-cb4d5534b972', 'ff1396ea-664c-4c80-b654-2136da431207', 'Preparation', 'a9a63d8d-437a-4d5b-a580-cb4d5534b972'),
	('Cremoso de Café', '7599c056-95fc-46b1-9e2a-162bcecb00e2', 'ff1396ea-664c-4c80-b654-2136da431207', 'Preparation', '7599c056-95fc-46b1-9e2a-162bcecb00e2'),
	('Mezcla de Ingredientes', '8b830d29-ad95-48c9-b352-296d3adaa4dc', 'dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', 'Preparation', '8b830d29-ad95-48c9-b352-296d3adaa4dc'),
	('Mushy Peas', 'cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Preparation', 'cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd'),
	('Crema Mascarpone', '4f74e07a-9099-43b8-8237-328da52def00', 'ff1396ea-664c-4c80-b654-2136da431207', 'Preparation', '4f74e07a-9099-43b8-8237-328da52def00'),
	('Cauliflower Foam', '4bc9f164-9169-4b0a-bacb-3af5f5c34f27', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', '4bc9f164-9169-4b0a-bacb-3af5f5c34f27'),
	('Coffee', '214ea2d4-b92a-4b78-af05-7e09f66f5461', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', '214ea2d4-b92a-4b78-af05-7e09f66f5461'),
	('Poached Leek', '922c20fe-e228-498c-a850-3303986ac0cb', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Preparation', '922c20fe-e228-498c-a850-3303986ac0cb'),
	('Cauliflower Foam', '3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369', '2010da74-6360-44c5-9b63-db0cd17a6530', 'Preparation', '3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369'),
	('Bizcocho de Zanahoria', '9c975cb7-dae7-4ea7-af98-f59b77ae37fd', '7667066b-6a66-4fbf-8902-625d535798dc', 'Preparation', '9c975cb7-dae7-4ea7-af98-f59b77ae37fd'),
	('Cauliflower Mash', '436e84a1-b015-4d80-8099-101f9a568a72', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', '436e84a1-b015-4d80-8099-101f9a568a72'),
	('Crispy Fish Sticks', '936b3fe1-8afa-42b8-b44a-17a9bd4c429d', 'ff3f850e-a473-43d9-9520-a9959be26dbd', 'Preparation', '936b3fe1-8afa-42b8-b44a-17a9bd4c429d'),
	('Caramelo Miso Mixture', 'bbd2273a-31e5-41b6-99f9-bc9836932d59', 'aa5f824e-051e-497a-822f-c8497480a038', 'Preparation', 'bbd2273a-31e5-41b6-99f9-bc9836932d59'),
	('Ssamjang Dip', 'cf03a865-782a-43bf-a7ed-fdf339aef463', '2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'Preparation', 'cf03a865-782a-43bf-a7ed-fdf339aef463'),
	('Poached Leek', '3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Preparation', '3c205f62-ce9c-4a30-9f49-c7ba6e17baf4'),
	('Mezcla de Nata y Azúcar', '03b059cf-caf7-413e-9313-a52e546f2908', 'ff1396ea-664c-4c80-b654-2136da431207', 'Preparation', '03b059cf-caf7-413e-9313-a52e546f2908'),
	('Cauliflower Foam', 'd5a1e773-7b8c-4667-b069-aff4011a3e71', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Preparation', 'd5a1e773-7b8c-4667-b069-aff4011a3e71'),
	('Bizcocho Terengue', '0688ba42-e321-42b1-a29e-78a38ce7825f', 'ff1396ea-664c-4c80-b654-2136da431207', 'Preparation', '0688ba42-e321-42b1-a29e-78a38ce7825f'),
	('Leek Sauce', '0d03d7e2-d617-4e73-b350-0521b9ff8323', 'cde1379e-9447-4560-a7ec-b304619ece8f', 'Preparation', '0d03d7e2-d617-4e73-b350-0521b9ff8323'),
	('Leaf Sauce', '096fce76-eb2a-4fca-a30e-466e90c7347c', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', '096fce76-eb2a-4fca-a30e-466e90c7347c'),
	('Poached Leek', '7522635d-6321-4529-958e-a76b9198bc14', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', '7522635d-6321-4529-958e-a76b9198bc14'),
	('Leek Sauce', 'e5ebfe86-99be-4a62-9468-47ea78f86e05', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'Preparation', 'e5ebfe86-99be-4a62-9468-47ea78f86e05');


--
-- Data for Name: kitchen_invites; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."kitchen_invites" ("invite_id", "kitchen_id", "invite_code", "created_by", "created_at", "expires_at", "is_active", "max_uses", "current_uses") VALUES
	('9a732e8e-e9e2-4bbe-98ed-859ceffde664', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'oRsRWAXb', 'eb32943a-afee-4480-8a9d-c4e724668990', '2025-05-28 04:37:18.174807+00', '2025-05-29 04:37:17.947+00', true, 1, 0),
	('2eaddc84-8acb-4a73-abd2-0c129b05a193', '816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'HXeIYU5D', '15510383-6cd2-455f-9337-7e69da27678b', '2025-08-25 17:46:37.754503+00', '2025-09-04 17:46:37.536+00', true, 1, 0);


--
-- Data for Name: kitchen_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."kitchen_users" ("kitchen_id", "user_id", "is_admin") VALUES
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'a0466a40-9577-4d72-ba89-320138b87cf5', true),
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'eb32943a-afee-4480-8a9d-c4e724668990', true),
	('d353ecae-c56a-497f-ad99-aff7238cb44c', 'a96d2a87-d780-4aac-9a9d-5acc35995f3d', true),
	('20cf91d9-e07a-49ce-b9dc-1cdc67c5aed5', 'eb32943a-afee-4480-8a9d-c4e724668990', true),
	('060259ed-faae-4798-800e-eb4b710fe716', 'aa45ca26-8aa4-4cc8-aefc-bfccc9095519', true),
	('b6fac464-1cb7-4474-b109-917fa33d5d54', 'f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c', true),
	('dc9ed5aa-54c9-4df5-b9a4-959e71a39ef8', '62e1fa1a-5f81-465f-9cbb-418fa95526c3', true),
	('ff3f850e-a473-43d9-9520-a9959be26dbd', 'be7996aa-4555-4eb1-9832-9244ad1d66a3', true),
	('2010da74-6360-44c5-9b63-db0cd17a6530', '1ed4c627-5891-4805-801a-f521bf146e93', true),
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', '1ed4c627-5891-4805-801a-f521bf146e93', true),
	('10a99788-4b58-4e16-bc5e-c54500ec8255', '814076fa-5459-44de-a281-39617339670f', true),
	('aab23e0a-dfd6-4465-bdf5-f505aa0ec707', 'c9cdd2fd-42f2-4813-b9b1-0fa04996d270', true),
	('cbbc6877-4a0e-4e99-aa87-a5cf51132629', 'dc93a6ed-19b4-4576-8ebf-6b7d0e928ef7', true),
	('e3aff5a8-485d-4444-9747-70e889380a50', 'cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', true),
	('2dd4a91d-1e2d-42d2-8675-e113d7374418', '6de3dcac-68b8-48b3-8fd4-79f3e2ee560b', true),
	('b60cec46-af07-4760-973b-f60ffbbdb152', 'bd8f6c9a-a1c5-4f32-b512-d9ce889a5a69', true),
	('2ab0aeb0-c8e9-4df9-b32b-7a10dd18dbb6', 'f6ee302b-8550-4a16-9d40-484695473337', true),
	('72e47938-1abf-4570-a521-8dcf90af24fd', 'd56fed25-3bac-4aa7-8a61-822d8cb1cd3f', true),
	('9135f578-6e1c-4e43-82fe-8bc170da360b', '7acd597a-56c3-412b-b821-27e3c668cf2d', true),
	('ff1396ea-664c-4c80-b654-2136da431207', '7acd597a-56c3-412b-b821-27e3c668cf2d', true),
	('7599ce8e-26ae-49fb-b29f-50c9823f7bb0', 'ecf29cba-f0d6-4a33-a563-dcbafc920726', true),
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'aa45ca26-8aa4-4cc8-aefc-bfccc9095519', true),
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', 'a96d2a87-d780-4aac-9a9d-5acc35995f3d', true),
	('bdc44a77-6aaf-4039-bb52-d853fdff2364', '3a6970e0-6b0e-4ee0-9ad5-0b4368026f16', true),
	('ccb2c02f-8418-4808-af6c-a46806429207', '15510383-6cd2-455f-9337-7e69da27678b', true),
	('cde1379e-9447-4560-a7ec-b304619ece8f', 'f2a5b8e4-61b1-4d2c-95a3-fbb2aa47c240', true),
	('7667066b-6a66-4fbf-8902-625d535798dc', 'd2503c32-5e47-425c-aab1-81d2ca5c632d', true),
	('aa5f824e-051e-497a-822f-c8497480a038', '457736da-0fb6-4bc6-a1d8-83acb178997e', true),
	('b81b76b5-b301-4c15-954c-c1e282bd1262', '433f5e78-f323-4d61-98be-dc7ff8e395a1', true),
	('016543f4-aed2-4bd4-82f6-dc99b3f4b5a2', 'fc68eb4e-ed71-4ce2-a99e-0a28ff75a695', true),
	('36f6935a-e7de-44f5-b36c-75353d663fb6', 'a8b860f9-2109-458a-a48d-8369b63f387d', true),
	('d4fd22b5-b949-4b0f-a755-301d42fb3afb', 'a8b860f9-2109-458a-a48d-8369b63f387d', true),
	('816f8fdb-fedd-4e6e-899b-9c98513e49c5', '15510383-6cd2-455f-9337-7e69da27678b', true),
	('fc0d9881-3ac0-44b7-a81b-f094ccd5063b', '0dcd4f5d-2754-4d13-bb5f-4de969c0772f', true),
	('dd00cb07-8b38-4c14-9385-2bdf4bef16bb', '890c997f-8da9-4b2d-95e0-55aa18d994d9', true);


--
-- Data for Name: recipe_components; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."recipe_components" ("recipe_id", "component_id", "amount", "unit", "item") VALUES
	('62208202-6c71-4163-a408-0ad0a7f16915', '922c20fe-e228-498c-a850-3303986ac0cb', 23.5, 'prep', NULL),
	('62208202-6c71-4163-a408-0ad0a7f16915', 'de2c3bd6-4d72-4598-ba8d-bd401e505941', 1, 'prep', NULL),
	('62208202-6c71-4163-a408-0ad0a7f16915', '3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369', 0.67, 'prep', NULL),
	('5b66fd41-9a10-45b6-bde6-1e106a8cf143', '9c975cb7-dae7-4ea7-af98-f59b77ae37fd', 1, 'prep', NULL),
	('5b66fd41-9a10-45b6-bde6-1e106a8cf143', '568e5750-e786-4e22-bf9e-e4514fe1d817', 1, 'prep', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', '604146ff-a2ee-4927-925a-1ead9058a3bc', 5, 'g', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', '97164d98-e925-4c71-b687-5d56999744c7', 5, 'g', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', '21fc70b2-bd21-4dba-bd0c-c54bd7c9a69b', 100, 'g', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', 'c4d5cb44-41a8-494f-8f45-05f02176e955', 150, 'g', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', '0a88f9ef-a895-4b30-9010-98d0f6c4785a', 50, 'g', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', '89347441-ded6-4758-8563-d7e6d4428c15', 12.5, 'g', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', 'aaa6c03d-ea1c-4dcf-ad39-0197f03cc63b', 2.5, 'g', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', 'a907c585-f9cc-4d1b-9a72-bdb9182e0562', 7.5, 'ml', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', '2670f74a-9c4a-40b1-976f-ac4f88cb501d', 0.25, 'g', NULL),
	('ba462224-d3f6-4d91-922a-327a53207132', '958d5830-ad7f-4108-afa7-d624f1b356cd', 0.25, 'g', NULL),
	('412dc85f-1d16-463e-9de1-59d1317193fe', 'e1ff35de-02d2-4453-8241-d1d6f1e9e5e7', 125, 'g', NULL),
	('412dc85f-1d16-463e-9de1-59d1317193fe', 'c8200eb7-6285-42a2-af93-f50e51cf7858', 1, 'prep', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', '136c4469-76df-4d32-baf7-5255d45089af', 0.25, 'x', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', 'e3d9ccae-ab00-44b0-bca6-39e371c680dd', 0.25, 'x', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', 'f825d544-29da-4b6d-8847-cabc57a2300c', 0.25, 'g', NULL),
	('15881ec0-ce1a-4e66-ac69-f0202a0c2df7', '19272280-8cd2-42fe-98c8-6d13b089cea6', 0.25, 'g', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '59ba2856-6abf-40f1-8a06-f1b00cd05d53', 0.25, 'x', NULL),
	('0d16c807-a8eb-4cc6-ae5a-05f5660dbb45', '436e84a1-b015-4d80-8099-101f9a568a72', 1, 'prep', NULL),
	('0d16c807-a8eb-4cc6-ae5a-05f5660dbb45', 'b579f6f2-278e-4690-bc76-1d64e83f9eaf', 1, 'prep', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', 'c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', 1, 'prep', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '3ba1e5a5-15b4-45e1-b4fc-48a7c297b84f', 12.5, 'g', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '28754d06-6609-4287-a539-cf65d0c24e73', 25, 'ml', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '8a75c368-9445-472e-a083-aaf84afe6673', 0.25, 'g', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '40f8b1b3-77d6-43e7-ad75-9182ef830d6b', 0.125, 'g', NULL),
	('439d0356-2e93-43b8-a828-16fe3be928ea', '9bdb38fa-aba2-4eaf-adf9-e1353c99a3e6', 12.5, 'g', NULL),
	('39bd92b0-1b00-4ac2-b171-26aecda76102', '3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', 1, 'prep', NULL),
	('39bd92b0-1b00-4ac2-b171-26aecda76102', 'd5a1e773-7b8c-4667-b069-aff4011a3e71', 1, 'prep', NULL),
	('39bd92b0-1b00-4ac2-b171-26aecda76102', '0d03d7e2-d617-4e73-b350-0521b9ff8323', 1, 'prep', NULL),
	('046cf913-50c9-43b8-b2d8-ff483fffa7a6', '8b830d29-ad95-48c9-b352-296d3adaa4dc', 1, 'prep', NULL),
	('0b64294d-c603-4ebd-9a6d-181ebbc37fc2', '7522635d-6321-4529-958e-a76b9198bc14', 1, 'prep', NULL),
	('0b64294d-c603-4ebd-9a6d-181ebbc37fc2', '4bc9f164-9169-4b0a-bacb-3af5f5c34f27', 1, 'prep', NULL),
	('0b64294d-c603-4ebd-9a6d-181ebbc37fc2', 'e5ebfe86-99be-4a62-9468-47ea78f86e05', 1, 'prep', NULL),
	('57159ab4-f635-4158-afb9-18a7854fa0a3', '936b3fe1-8afa-42b8-b44a-17a9bd4c429d', 1, 'prep', NULL),
	('57159ab4-f635-4158-afb9-18a7854fa0a3', 'cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd', 1, 'prep', NULL),
	('74c79adc-1130-4e88-a8e1-5900dac84be7', 'd5c97843-b2e2-4b7d-9332-2a239387a136', 1, 'prep', NULL),
	('74c79adc-1130-4e88-a8e1-5900dac84be7', '450436ad-7471-4e54-b2af-64c395568055', 75, 'g', NULL),
	('74c79adc-1130-4e88-a8e1-5900dac84be7', '2d919b4b-9cd4-4f1a-bbb9-74e8054d2049', 1, 'cup', NULL),
	('74c79adc-1130-4e88-a8e1-5900dac84be7', 'a6e1453b-ff47-4aae-a75a-834f5db40728', 2.5, 'g', NULL),
	('c71a2128-59a7-4e9e-8ae3-6a51e7f2234f', 'cf03a865-782a-43bf-a7ed-fdf339aef463', 1, 'prep', NULL),
	('8ee812fc-f52f-488d-98d0-af4b1fea16d3', '0688ba42-e321-42b1-a29e-78a38ce7825f', 1, 'prep', NULL),
	('8ee812fc-f52f-488d-98d0-af4b1fea16d3', '7599c056-95fc-46b1-9e2a-162bcecb00e2', 1, 'prep', NULL),
	('8ee812fc-f52f-488d-98d0-af4b1fea16d3', 'a9a63d8d-437a-4d5b-a580-cb4d5534b972', 1, 'prep', NULL),
	('8ee812fc-f52f-488d-98d0-af4b1fea16d3', '4f74e07a-9099-43b8-8237-328da52def00', 1, 'prep', NULL),
	('76d10c78-8ee0-4998-a849-530a834a8a5b', '7522635d-6321-4529-958e-a76b9198bc14', 1, 'prep', NULL),
	('76d10c78-8ee0-4998-a849-530a834a8a5b', '4bc9f164-9169-4b0a-bacb-3af5f5c34f27', 1, 'prep', NULL),
	('76d10c78-8ee0-4998-a849-530a834a8a5b', '096fce76-eb2a-4fca-a30e-466e90c7347c', 1, 'prep', NULL),
	('214ea2d4-b92a-4b78-af05-7e09f66f5461', '2d919b4b-9cd4-4f1a-bbb9-74e8054d2049', 1, 'x', NULL),
	('cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd', '5fb46bc4-9ebb-404b-8abb-aea24ddfca43', 50, 'g', NULL),
	('cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd', '5dfac492-5371-4855-aa6e-882eaab83b53', 6.25, 'g', NULL),
	('cb96a6d2-9f6b-48ab-bcef-d35f6d1a54fd', '37935488-601e-4b74-a2d8-b0f460feeec9', 0.125, 'g', NULL),
	('7522635d-6321-4529-958e-a76b9198bc14', 'c70f8b84-19ee-4146-b7db-732a2258ba73', 0.75, 'x', NULL),
	('d5c97843-b2e2-4b7d-9332-2a239387a136', 'a01325d4-5984-4f6a-a35b-0c31ab713060', 1.5, 'x', NULL),
	('d5c97843-b2e2-4b7d-9332-2a239387a136', '4b7e8a5e-3b4b-4816-91eb-36016d019e2a', 57.5, 'g', NULL),
	('d5c97843-b2e2-4b7d-9332-2a239387a136', '9e79bee3-d6be-499a-8b87-6df5e7210ab9', 125, 'g', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '8dfdeaa4-2661-4c7e-9f06-366d20d65403', 113.75, 'g', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '0963cc2e-e17b-4646-88a3-41a17b181adb', 0.25, 'x', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', 'aaa6c03d-ea1c-4dcf-ad39-0197f03cc63b', 0.5, 'x', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '3a5d30f3-e349-4581-af3a-a3ef7f0c54b8', 72.5, 'g', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '0a88f9ef-a895-4b30-9010-98d0f6c4785a', 0.5, 'x', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '4cc59132-7397-4fa3-82e6-6033720d0743', 0.5, 'x', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '3ac6f64e-26ad-46a0-be41-ee7f045774f0', 0.25, 'tbsp', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', 'b3ac9df1-f21b-42dc-8bee-274d7f5286eb', 0.0625, 'tsp', NULL),
	('b579f6f2-278e-4690-bc76-1d64e83f9eaf', '8206414f-d29c-4767-98b9-37d4562f3355', 0.25, 'tbsp', NULL),
	('4bc9f164-9169-4b0a-bacb-3af5f5c34f27', 'bdaadae9-f355-4493-a91b-36fd643d215c', 0.25, 'kg', NULL),
	('4bc9f164-9169-4b0a-bacb-3af5f5c34f27', '9bb04a06-aa40-4987-83ac-0491a8434617', 25, 'g', NULL),
	('4bc9f164-9169-4b0a-bacb-3af5f5c34f27', 'b5f29b90-d84c-499e-8238-fd37da38fdf8', 87.5, 'g', NULL),
	('436e84a1-b015-4d80-8099-101f9a568a72', 'bdaadae9-f355-4493-a91b-36fd643d215c', 0.25, 'x', NULL),
	('436e84a1-b015-4d80-8099-101f9a568a72', '8206414f-d29c-4767-98b9-37d4562f3355', 0.25, 'tbsp', NULL),
	('436e84a1-b015-4d80-8099-101f9a568a72', 'b3ac9df1-f21b-42dc-8bee-274d7f5286eb', 0.0625, 'tsp', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', '80e6120b-a237-42d1-9083-71df2765adfd', 8, 'l', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', '7887ed5a-14a6-4139-ae99-a10d7dde3698', 3, 'l', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', '85e9ac1d-f90e-4245-bccd-f6bcdfe895a8', 3.25, 'kg', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', 'dcbfcacc-14ef-40e5-9e71-82b2ebdde77e', 2.35, 'kg', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', 'a91ce3b0-e5c6-4c75-9291-ee4dfd652829', 3.6, 'kg', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', '79a23778-6a71-4c89-9811-d406491c7056', 300, 'g', NULL),
	('8b830d29-ad95-48c9-b352-296d3adaa4dc', '4cf07418-720d-4d92-a899-f046df18fdda', 40, 'g', NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', 'bf4e92df-229e-4b03-91c5-0e195f4ddd0d', 100, 'g', NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', 'beddd9dc-49ad-4245-8840-ae5d15ab0ab2', 50, 'g', NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', '133a5f1a-d51b-4f5d-bd6e-53fbb72b2bb6', 0.5, 'x', NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', '08a9337d-9917-4239-bce5-08ce58a716ae', 25, 'g', NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', '37935488-601e-4b74-a2d8-b0f460feeec9', 0.25, 'g', NULL),
	('936b3fe1-8afa-42b8-b44a-17a9bd4c429d', 'b76e181a-fa94-4d2f-ab08-1d94a7da9692', 0.125, 'g', NULL),
	('7522635d-6321-4529-958e-a76b9198bc14', '5f9b0714-f3dc-4720-89ac-0ed7cbdcca8c', 50, 'g', NULL),
	('7522635d-6321-4529-958e-a76b9198bc14', '718cb336-aad9-4479-bf8d-0bb5e95ce697', 50, 'g', NULL),
	('e5ebfe86-99be-4a62-9468-47ea78f86e05', 'c70f8b84-19ee-4146-b7db-732a2258ba73', 0.25, 'x', NULL),
	('e5ebfe86-99be-4a62-9468-47ea78f86e05', '9bb04a06-aa40-4987-83ac-0491a8434617', 25, 'g', NULL),
	('c8200eb7-6285-42a2-af93-f50e51cf7858', 'e2da5708-64e2-4e0a-b63b-16d51b6e3b5d', 0.015625, 'x', NULL),
	('c8200eb7-6285-42a2-af93-f50e51cf7858', 'f046b00a-644f-4dec-84c6-9cee72cdcfe3', 0.03125, 'x', NULL),
	('c8200eb7-6285-42a2-af93-f50e51cf7858', '178bc85d-9222-4491-ac9c-0050471d2932', 0.703125, 'ml', NULL),
	('c8200eb7-6285-42a2-af93-f50e51cf7858', 'd3959d7b-02f9-4bb2-af9a-7216cabd039f', 0.15625, 'g', NULL),
	('c8200eb7-6285-42a2-af93-f50e51cf7858', '3a5193c0-c7dd-48db-8833-e3579d2eaa9f', 0.234375, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', '2439f7b2-bc65-495b-8081-449312930407', 1350, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', 'bc06aad6-aff0-4ca4-8535-95cd05bc4f2a', 465, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', 'ec35f115-3d63-4e12-94a8-6dd1c22beec4', 7, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', 'c2d969e8-2667-4066-bd05-dca75d0f007f', 15, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', '0eca83bc-aef2-4149-bde4-e18024b2c56a', 2, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', '3992d161-1033-4c27-9376-88370cda94f8', 44, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', '2f2f6ceb-d34f-4f41-b61e-4b91d6d0e992', 45, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', '4adacd16-bf40-41d9-84c8-d3e07f544771', 35, 'g', NULL),
	('fa1bdca2-c244-48a5-b3ab-a1f16562677c', '1015d290-9436-4831-871f-ad69ab0aff33', 35, 'g', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', '548f2f4a-a023-4947-99c7-f03e156632f2', 0.5, 'x', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', '821a10e4-1dd5-4d9e-a036-655af28cff98', 120, 'ml', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', '400c76f3-35af-4dca-adf0-c5e6764b6cde', 120, 'ml', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', '4adacd16-bf40-41d9-84c8-d3e07f544771', 1, 'x', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', 'e79ec050-3aae-4b9d-88eb-3ad5fee3e542', 1, 'x', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', 'f7adbec0-9c31-4f34-a6de-c0ffdad96ce6', 15, 'ml', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', 'f7a837e1-8a6f-44e7-aa09-3890dbae8810', 7.5, 'ml', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', '25376124-9462-4d1f-81cc-9b3b7e09b1f5', 15, 'ml', NULL),
	('cf03a865-782a-43bf-a7ed-fdf339aef463', '3a40248d-334b-485a-87d6-24de429d7d50', 0.625, 'ml', NULL),
	('eba91d21-3ae0-4b0f-aae6-ed99f4d1694e', 'f2ac327b-6abc-4313-9b21-576cc214f92e', 62.5, 'g', NULL),
	('eba91d21-3ae0-4b0f-aae6-ed99f4d1694e', '946f20c4-8fde-4f03-95e0-b028770c1478', 4, 'g', NULL),
	('03b059cf-caf7-413e-9313-a52e546f2908', '5994d39d-5274-43c7-a5a5-12ac3856aa58', 150, 'g', NULL),
	('03b059cf-caf7-413e-9313-a52e546f2908', '08b51058-971e-4f60-86c7-6374238ef989', 40, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', 'b139ae68-e456-4b97-8955-58cf4cdf0f3e', 30, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', 'b4e15865-667f-4760-ae0f-80f45313a4ed', 30, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', '60a34f12-ffb2-4de9-a9e8-3bcea79796f7', 30, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', 'a9386b71-639e-4267-b41c-c7175894ff15', 30, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', 'c8b289fb-6860-4f07-946c-204d705ec7b7', 44, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', '56c584ad-adc5-4a5f-897e-78d17d0364f7', 1.25, 'g', NULL),
	('a9a63d8d-437a-4d5b-a580-cb4d5534b972', '08b51058-971e-4f60-86c7-6374238ef989', 2.5, 'g', NULL),
	('0688ba42-e321-42b1-a29e-78a38ce7825f', '9fff95bc-f887-4766-8a96-40e985b5758a', 12, 'g', NULL),
	('0688ba42-e321-42b1-a29e-78a38ce7825f', '08b51058-971e-4f60-86c7-6374238ef989', 7.3, 'g', NULL),
	('0688ba42-e321-42b1-a29e-78a38ce7825f', '248eba5c-0253-4306-873c-05764c5397c9', 6.65, 'g', NULL),
	('0688ba42-e321-42b1-a29e-78a38ce7825f', '9d8e2e18-e8c7-4fa3-b2bd-885732d380f4', 4.15, 'g', NULL),
	('0688ba42-e321-42b1-a29e-78a38ce7825f', 'a9386b71-639e-4267-b41c-c7175894ff15', 4.3, 'g', NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', 'b4e15865-667f-4760-ae0f-80f45313a4ed', 31.5, 'g', NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', '5994d39d-5274-43c7-a5a5-12ac3856aa58', 13.5, 'g', NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', 'c8b289fb-6860-4f07-946c-204d705ec7b7', 9, 'g', NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', '08b51058-971e-4f60-86c7-6374238ef989', 0.9, 'g', NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', 'a34b8c0b-0f0a-4bd2-af38-1ff73c55b3f1', 30, 'g', NULL),
	('7599c056-95fc-46b1-9e2a-162bcecb00e2', '946f20c4-8fde-4f03-95e0-b028770c1478', 0.4, 'g', NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', '08b51058-971e-4f60-86c7-6374238ef989', 160, 'g', NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', '5994d39d-5274-43c7-a5a5-12ac3856aa58', 400, 'g', NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', '80b8437e-6d8d-42ce-96c2-3c7c7b946418', 1, 'kg', NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', '946f20c4-8fde-4f03-95e0-b028770c1478', 14, 'g', NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', 'ae82dce6-4929-4b83-83c7-5e8fb0444228', 1, 'x', NULL),
	('4f74e07a-9099-43b8-8237-328da52def00', 'f2ac327b-6abc-4313-9b21-576cc214f92e', 250, 'g', NULL),
	('096fce76-eb2a-4fca-a30e-466e90c7347c', '38e30063-2710-41d7-ade2-57883db76ffb', 1.72413793103448, 'g', NULL),
	('096fce76-eb2a-4fca-a30e-466e90c7347c', '4d2150da-8fb6-4740-b093-0255b5305f8f', 1.72413793103448, 'ml', NULL),
	('922c20fe-e228-498c-a850-3303986ac0cb', '895359d5-c043-45ea-a7c8-8179fee53db1', 0.0319148936170213, 'x', NULL),
	('922c20fe-e228-498c-a850-3303986ac0cb', '6bd6070e-53a1-4c0e-af74-98aad4f2fc9d', 2.12765957446809, 'g', NULL),
	('922c20fe-e228-498c-a850-3303986ac0cb', '57802cb6-c5b1-4543-a348-828247181453', 2.12765957446809, 'g', NULL),
	('de2c3bd6-4d72-4598-ba8d-bd401e505941', '895359d5-c043-45ea-a7c8-8179fee53db1', 0.25, 'x', NULL),
	('de2c3bd6-4d72-4598-ba8d-bd401e505941', '8e66b973-71ad-4c9e-aa57-73c72b21c0ce', 25, 'g', NULL),
	('3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369', '43ed9eb8-5eaf-4e6d-a3ad-69a9e8d25f21', 0.25, 'kg', NULL),
	('3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369', '63463616-94b3-47ec-8be3-7eec3a3f599c', 87.5, 'g', NULL),
	('3f5c4b0f-05f4-4dd3-bac8-e3d0532c7369', '8e66b973-71ad-4c9e-aa57-73c72b21c0ce', 25, 'g', NULL),
	('df188431-52e2-4c2a-bee9-501026c15dc3', '982bb972-29f7-4352-a361-74655299a7c3', 360, 'g', NULL),
	('df188431-52e2-4c2a-bee9-501026c15dc3', '7995d592-abdb-4dcd-8617-f1cc0d8ccdc7', 444, 'g', NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', '5b0c7ae8-cbb5-4ebe-a0cb-98eee18ac5ab', 25, 'g', NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', 'c24f7c9a-a596-47ee-96a3-4cc06001563b', 37.5, 'g', NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', '0c44198c-3a00-49ce-a67e-17861e35b733', 25, 'g', NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', '119d2a50-4342-4400-be28-f9bec58c94aa', 1.5, 'g', NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', '035fbcee-541b-4594-8e4f-0bde74899bc2', 1.25, 'g', NULL),
	('9c975cb7-dae7-4ea7-af98-f59b77ae37fd', '0565be00-076b-4aa2-ad38-91e2dde6f062', 0.125, 'g', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', '3f5da04c-3de2-4690-8c58-bd460914edd6', 87.5, 'ml', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', 'f9b95743-d921-4f82-92dd-c38af215a98e', 0.125, 'x', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', '58ccb6cf-429a-401c-b3dc-9a89bc4e4670', 9.375, 'g', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', '52eb11d2-83e9-4a89-a73a-b067ac388d0e', 59.375, 'ml', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', '8833d88e-4af5-43d3-a635-9a6209f4f0c9', 43.75, 'g', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', 'd178d591-838d-4d07-b8fe-0156f06ec6d6', 0.75, 'g', NULL),
	('568e5750-e786-4e22-bf9e-e4514fe1d817', '8c0dd368-519e-49aa-bbc5-66c72d291a91', 0.25, 'g', NULL),
	('bbd2273a-31e5-41b6-99f9-bc9836932d59', '52d673c4-de2b-4c2c-bb8a-b389b13622cf', 1, 'kg', NULL),
	('bbd2273a-31e5-41b6-99f9-bc9836932d59', 'bb73bc38-fb95-42d5-8952-4b19d93822be', 530, 'g', NULL),
	('bbd2273a-31e5-41b6-99f9-bc9836932d59', '18eefb9d-543d-43dc-9ee1-d3f01593f77d', 140, 'g', NULL),
	('bbd2273a-31e5-41b6-99f9-bc9836932d59', '4d6a3e90-0982-4e8e-a9c5-298bb5db5182', 70, 'g', NULL),
	('bbd2273a-31e5-41b6-99f9-bc9836932d59', '1d91ae38-efe8-495b-b830-8d127962c8ce', 6, 'g', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', '9e29a99c-4a03-4d05-8c09-70ac9e60207e', 0.1, 'x', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', '478278ac-8159-4972-9afa-80b5da3d0878', 0.05, 'x', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', 'e4f6bb2f-99aa-4a43-9a84-6333032dd16c', 0.05, 'x', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', '9b66ca37-4af5-4531-bdc6-df9ca4b016bd', 0.05, 'x', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', '3f6b8518-dd15-4d64-82e3-56ece7be13e9', 0.05, 'x', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', '7090a837-e93a-4844-aac8-2ad18ccb4750', 0.5, 'g', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', '68896111-aff2-4105-91d9-480601f1ba42', 0.005, 'g', NULL),
	('c3f6ce60-4115-4b71-bfbe-a60dfc15cbed', 'b051a071-aa10-46dd-b4e1-1a265bb8b4d1', 0.05, 'x', NULL),
	('3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', '75c24432-e7cf-4b99-ba4c-1fc33b51b062', 0.0375, 'x', NULL),
	('3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', '8109cd45-db10-48c2-849a-5786226dae44', 2.5, 'ml', NULL),
	('3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', '50568ee9-0804-4e34-9c57-da82255dcef8', 2.5, 'g', NULL),
	('3c205f62-ce9c-4a30-9f49-c7ba6e17baf4', 'e7d9a313-29ef-4f27-bed8-5d0bee0c281a', 2.5, 'g', NULL),
	('d5a1e773-7b8c-4667-b069-aff4011a3e71', 'e1f16002-72c0-4799-8c4e-583cecf727cd', 0.0125, 'kg', NULL),
	('d5a1e773-7b8c-4667-b069-aff4011a3e71', '6d050e35-43d8-48fb-b35d-8ae1219f4823', 1.25, 'g', NULL),
	('d5a1e773-7b8c-4667-b069-aff4011a3e71', 'c708aee7-e214-47e3-81c6-0b04852aefb3', 4.375, 'g', NULL),
	('0d03d7e2-d617-4e73-b350-0521b9ff8323', '75c24432-e7cf-4b99-ba4c-1fc33b51b062', 0.0125, 'x', NULL),
	('0d03d7e2-d617-4e73-b350-0521b9ff8323', 'c3fd075a-9b54-44ee-a533-850e75c83325', 2.5, 'ml', NULL);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."users" ("user_id", "user_fullname", "user_email", "created_at", "updated_at") VALUES
	('a8b860f9-2109-458a-a48d-8369b63f387d', 'Adrián López', 'adrian@colmadocarpanta.es', '2025-08-20 09:04:25.630142+00', '2025-08-20 09:04:43.983643+00'),
	('0dcd4f5d-2754-4d13-bb5f-4de969c0772f', 'Guillem Pico Maya', 'gpicomaya@gmail.com', '2025-09-01 18:51:19.899901+00', '2025-09-01 18:51:19.899901+00'),
	('7acd597a-56c3-412b-b821-27e3c668cf2d', 'Maxime Petit ', 'maximepetitpatisserie@gmail.com', '2025-07-31 13:04:46.771227+00', '2025-07-31 13:04:59.807745+00'),
	('dc93a6ed-19b4-4576-8ebf-6b7d0e928ef7', 'Ignasi Frechoso', 'ifrechoso@gmail.com', '2025-07-11 22:10:27.993323+00', '2025-09-01 22:05:19.085188+00'),
	('ecf29cba-f0d6-4a33-a563-dcbafc920726', NULL, '6cc4zpwnkv@privaterelay.appleid.com', '2025-07-31 21:20:57.722187+00', '2025-07-31 21:20:57.722187+00'),
	('890c997f-8da9-4b2d-95e0-55aa18d994d9', NULL, 'qcyw8b85fz@privaterelay.appleid.com', '2025-09-03 14:44:01.059838+00', '2025-09-03 14:44:01.059838+00'),
	('a0466a40-9577-4d72-ba89-320138b87cf5', 'James Franco', 'mtspana@verizon.net', '2025-05-25 20:51:44.482437+00', '2025-05-25 20:51:44.482437+00'),
	('1ed4c627-5891-4805-801a-f521bf146e93', 'Yago Ferretti', 'yago@foodweb.ai', '2025-07-11 15:54:58.807598+00', '2025-08-01 15:11:17.928504+00'),
	('a96d2a87-d780-4aac-9a9d-5acc35995f3d', 'Andrew Sweeney', 'sweeney5285@gmail.com', '2025-06-11 01:24:13.586859+00', '2025-06-11 01:24:13.586859+00'),
	('3a6970e0-6b0e-4ee0-9ad5-0b4368026f16', 'Christos ', 'chris.maniakis@gmail.com', '2025-08-02 18:37:01.853739+00', '2025-08-02 18:37:17.478813+00'),
	('aa45ca26-8aa4-4cc8-aefc-bfccc9095519', NULL, 'apple@apple.com', '2025-07-03 18:36:43.697447+00', '2025-07-03 18:36:43.697447+00'),
	('f1f21f3c-e6bf-4fd2-b8d9-267e587e6a8c', 'Imma g prats', 'immagprats@hotmail.com', '2025-07-09 15:24:51.607644+00', '2025-07-09 15:24:51.607644+00'),
	('d56fed25-3bac-4aa7-8a61-822d8cb1cd3f', NULL, 'google@android.com', '2025-07-09 17:35:13.253824+00', '2025-07-09 17:35:13.253824+00'),
	('62e1fa1a-5f81-465f-9cbb-418fa95526c3', 'Marga Lee', 'maggie.q.l@hotmail.com', '2025-07-10 16:59:26.769513+00', '2025-07-10 16:59:26.769513+00'),
	('be7996aa-4555-4eb1-9832-9244ad1d66a3', 'Vitika Agarwal', 'vitika.agarwal@gmail.com', '2025-07-11 10:48:47.192639+00', '2025-07-11 10:48:47.192639+00'),
	('814076fa-5459-44de-a281-39617339670f', 'Luca Piazzolla', 'piazzolla.luca93@gmail.com', '2025-07-11 17:01:50.238619+00', '2025-07-11 17:01:50.238619+00'),
	('c9cdd2fd-42f2-4813-b9b1-0fa04996d270', 'Fabian Isamat', 'fabianisamat@icloud.com', '2025-07-12 08:26:23.49531+00', '2025-07-12 08:26:23.49531+00'),
	('6de3dcac-68b8-48b3-8fd4-79f3e2ee560b', 'Arnav', 'aa5507@columbia.edu', '2025-07-17 10:26:18.767671+00', '2025-07-17 10:26:18.767671+00'),
	('2cb67821-d674-478e-8c2d-f5ba8392d0f0', 'Yagi', 'yagofererri@gmail.com', '2025-08-08 10:37:53.000061+00', '2025-08-08 10:37:53.000061+00'),
	('bd8f6c9a-a1c5-4f32-b512-d9ce889a5a69', 'Vincenzo Matonti ', 'vincent.matont@hotmail.it', '2025-07-17 21:55:32.87238+00', '2025-07-17 21:55:32.87238+00'),
	('f6ee302b-8550-4a16-9d40-484695473337', 'Ian Durkin', 'iandurkin14@gmail.com', '2025-07-24 11:04:28.644896+00', '2025-07-24 11:04:28.644896+00'),
	('eb32943a-afee-4480-8a9d-c4e724668990', 'Arnav Agarwal', 'arnav@foodweb.ai', '2025-05-14 03:01:59.84419+00', '2025-08-08 17:52:15.910636+00'),
	('d2503c32-5e47-425c-aab1-81d2ca5c632d', 'Imma G Prats', 'deverdi154@gmail.com', '2025-08-10 15:51:33.013409+00', '2025-08-10 15:51:33.013409+00'),
	('15510383-6cd2-455f-9337-7e69da27678b', 'Yago Ferretti Gonzalez', 'yagoferretti@gmail.com', '2025-08-08 10:27:28.980083+00', '2025-08-10 16:23:32.040605+00'),
	('cba1e62a-bf31-40a0-8387-7fa37e1c4ef1', 'mimmo ferretti', 'mimmoferretti@hotmail.com', '2025-07-15 16:10:13.250484+00', '2025-08-12 13:58:38.912044+00'),
	('457736da-0fb6-4bc6-a1d8-83acb178997e', 'Sebastián Vallejo', 'sebastianvallejobetancourt@gmail.com', '2025-08-12 16:25:57.368571+00', '2025-08-12 16:25:57.368571+00'),
	('433f5e78-f323-4d61-98be-dc7ff8e395a1', 'Nick Gool', 'nickgoolbcn@gmail.com', '2025-08-13 15:36:28.282487+00', '2025-08-13 15:36:52.180294+00'),
	('fc68eb4e-ed71-4ce2-a99e-0a28ff75a695', 'Gregoire Dettai', 'gregoire@kitchensoftomorrow.com', '2025-08-13 16:11:10.51966+00', '2025-08-13 16:11:27.672288+00'),
	('f2a5b8e4-61b1-4d2c-95a3-fbb2aa47c240', 'Arnav Agarwal', 'arnava1304@gmail.com', '2025-08-08 17:08:33.329988+00', '2025-08-19 19:29:39.364893+00');


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--

INSERT INTO "storage"."buckets" ("id", "name", "owner", "created_at", "updated_at", "public", "avif_autodetection", "file_size_limit", "allowed_mime_types", "owner_id") VALUES
	('item-images', 'item-images', NULL, '2025-05-20 03:02:58.646055+00', '2025-05-20 03:02:58.646055+00', false, false, NULL, NULL, NULL);


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1639, true);

--
-- PostgreSQL database dump complete
--

RESET ALL;
